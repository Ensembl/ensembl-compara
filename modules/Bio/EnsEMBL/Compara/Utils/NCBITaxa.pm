=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::Utils::NCBITaxa

=head1 DESCRIPTION

Utility module for handling NCBI Taxonomy data.

=cut

package Bio::EnsEMBL::Compara::Utils::NCBITaxa;

use strict;
use warnings;

use List::Util qw(sum);

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref check_ref);

use base qw(Exporter);


our @EXPORT_OK = qw(
    sync_taxon_ids_by_genome_db_id
);


sub _fetch_genome_taxa_mapping {
    my ($sql_helper, $table_name, $genome_db_ids) = @_;

    my $sql = qq/
        SELECT DISTINCT genome_db_id, taxon_id
        FROM $table_name
        WHERE genome_db_id IS NOT NULL
    /;

    if (defined $genome_db_ids
            && check_ref($genome_db_ids, 'ARRAY')
            && scalar(@{$genome_db_ids}) > 0) {
        my $placeholders = '(' . join(',', ('?') x @{$genome_db_ids}) . ')';
        $sql .= " AND genome_db_id IN $placeholders";
    } else {
        $genome_db_ids = [];
    }

    my $results = $sql_helper->execute( -SQL => $sql,  -PARAMS => $genome_db_ids, -USE_HASHREFS => 1 );

    my %genome_taxa_map;
    foreach my $row (@{$results}) {
        my $gdb_id = $row->{'genome_db_id'};
        my $taxon_id = $row->{'taxon_id'};
        push(@{$genome_taxa_map{$gdb_id}}, $taxon_id);
    }

    return \%genome_taxa_map;
}


=head2 sync_taxon_ids_by_genome_db_id

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : string $src_table
  Arg[3]      : string $dest_table
  Arg[4]      : (optional) arrayref of integers $genome_db_ids
  Example     : sync_taxon_ids_by_genome_db_id($compara_dba, 'genome_db', 'species_tree_node');
  Description : Given a source and destination table in the specified Compara database,
                this function will identify the mapping of genome_db_id to taxon_id in
                each table, and will try to resolve any discrepancies by updating the
                destination table so that it matches the source table.
  Returntype  : none
  Exceptions  : throws if an argument test fails, or if any genome_db_id in
                the source table is associated with multiple taxon_id values
  Status      : Experimental

=cut

sub sync_taxon_ids_by_genome_db_id {
    my ($compara_dba, $src_table, $dest_table, $genome_db_ids) = @_;

    assert_ref($compara_dba, 'Bio::EnsEMBL::Compara::DBSQL::DBAdaptor', 'compara_dba');
    throw('NCBITaxa::sync_taxon_ids_by_genome_db_id() requires a $src_table') unless $src_table;
    throw('NCBITaxa::sync_taxon_ids_by_genome_db_id() requires a $dest_table') unless $dest_table;

    my $helper = $compara_dba->dbc->sql_helper;

    my $src_map = _fetch_genome_taxa_mapping($helper, $src_table, $genome_db_ids);
    my $dest_map = _fetch_genome_taxa_mapping($helper, $dest_table, $genome_db_ids);
    my @common_gdb_ids = grep { exists $dest_map->{$_} } keys %{$src_map};

    my %sync_map;
    foreach my $gdb_id (sort { $a <=> $b } @common_gdb_ids) {
        my $src_taxon_ids = $src_map->{$gdb_id};

        my $src_taxon_id;
        if (scalar(@{$src_taxon_ids}) == 1) {
            $src_taxon_id = $src_taxon_ids->[0];
        } else {  # i.e. scalar(@{$src_taxon_ids}) > 1
            throw(
                "cannot sync taxon_ids for genome_db_id $gdb_id because"
                . " it is associated with multiple taxon_ids in $src_table"
            )
        }

        my $dest_taxon_ids = $dest_map->{$gdb_id};
        if (scalar(@{$dest_taxon_ids}) == 1) {
            my $dest_taxon_id = $dest_taxon_ids->[0];
            if ((defined($src_taxon_id) xor defined($dest_taxon_id))
                    || (defined($src_taxon_id) && defined($dest_taxon_id) && $dest_taxon_id != $src_taxon_id)) {
                $sync_map{$gdb_id} = $src_taxon_id;
            }
        } else {  # i.e. scalar(@{$dest_taxon_ids}) > 1
            $sync_map{$gdb_id} = $src_taxon_id;
        }
    }

    foreach my $gdb_id (sort { $a <=> $b } keys %sync_map) {
        my $taxon_id = $sync_map{$gdb_id};
        my $update_statement = qq/UPDATE $dest_table SET taxon_id = ? WHERE genome_db_id = ?/;
        $helper->execute_update( -SQL => $update_statement, -PARAMS => [$taxon_id, $gdb_id] );
    }
}


1;
