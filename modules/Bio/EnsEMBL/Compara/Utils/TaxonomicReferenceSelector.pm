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

Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector

=head1 DESCRIPTION

Utility methods for collecting taxonomic ranks and matching to taxonomic references

=cut

package Bio::EnsEMBL::Compara::Utils::TaxonomicReferenceSelector;

use strict;
use warnings;
use base qw(Exporter);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;;
use List::Util;

our %EXPORT_TAGS;
our @EXPORT_OK;

@EXPORT_OK = qw(
    collect_reference_classification
    match_query_to_reference_taxonomy
    collect_species_set_dirs
);
%EXPORT_TAGS = (
  all     => [@EXPORT_OK]
);

=head2 collect_reference_classification

    Arg[1]     :  (string) $reference_db or Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $reference_db
    Description:  Collect reference ncbi taxonomic classifications by species_set. This expects a reference
                  specific compara reference database with taxonomically named species_sets.
    Example    : my $taxon_clade = collect_reference_classification('reference_db');
    Return     :  (arrayref) list of species_set names.
    Exceptions :  None.

=cut

sub collect_reference_classification {
    my $reference_db = shift;

    my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($reference_db);
    my $ss_adaptor = $dba->get_SpeciesSetAdaptor->fetch_all();
    my @ss_names   = map {$_->name()} @{$ss_adaptor};
    my @clean_ss   = grep ( s/^collection\-//g, @ss_names );
    @clean_ss      = sort @clean_ss;
    return \@clean_ss;
}

=head2 match_query_to_reference_taxonomy

    Arg[1]     :  Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
    Arg[2]     :  Bio::EnsEMBL::Compara::GenomeDB
    Arg[3]     :  (optional) Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $reference_dba
                  Either/or
    Arg[4]     :  (optional) (arrayref) $taxon_list
    Description:  Match starting from lowest taxonomic rank climbing, returning string variable at first match.
    Example    : my $ref_clade = match_query_to_reference_taxonomy($compara_dba, $genome_db);
    Return     :  (string) $taxon_name or undef
    Exceptions :  Throws if both (or neither) $taxon_list and $reference_dba are provided

=cut

sub match_query_to_reference_taxonomy {
    my ($genome_db, $reference_dba, $taxon_list) = (@_);

    throw ("taxon_list and reference_dba are mutually exclusive, pick one") if $taxon_list && $reference_dba;
    throw ("Either taxon_list or reference_dba need to be provided") unless $taxon_list || $reference_dba;

    my @taxon_list = $taxon_list ? @$taxon_list : @{collect_reference_classification($reference_dba)};
    my $parent     = $genome_db->taxon->parent;

    while ( $parent->name ne "root" ) {
        if ( grep { lc($parent->name) eq $_ } @taxon_list ) {
            return 'collection-' . lc($parent->name);
        }
        else {
            $parent = $parent->parent;
        }
    }

    return undef;
}

=head2 collect_species_set_dirs

    Arg[1]     :  (string) $reference_db or Bio::EnsEMBL::Compara::DBSQL::DBAdaptor
    Arg[2]     :  (string) $taxa_name
    Arg[3]     :  (string) $ref_dump_dir
    Description:  Collect list of dir_revhash paths for all genomes in taxonomic clade by species_set.
                  Does not return absolute paths, only the paths starting at the reverse hash of gdb, so
                  will require appending to dump path dir or working dir etc.
    Example    : my $dir_paths = collect_species_set_dirs($compara_dba, $ncbi_taxa_name);
    Return     :  (arrayref of hashes) list of directories
    Exceptions :  None.

=cut

sub collect_species_set_dirs {
    my ($reference_db, $taxa_name, $ref_dump_dir) = (@_);

    my $dba          = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($reference_db);
    my $ss_adaptor   = $dba->get_SpeciesSetAdaptor;
    my $gdb_adaptor  = $dba->get_GenomeDBAdaptor;
    $gdb_adaptor->dump_dir_location($ref_dump_dir);
    my $species_set  = $ss_adaptor->fetch_collection_by_name($taxa_name);
    my $genome_dbs   = $species_set->genome_dbs;
    my @genome_files;

    foreach my $gdb ( @$genome_dbs ) {
        my $ref_fasta   = $gdb->_get_members_dump_path($ref_dump_dir); # standard fasta file
        my $ref_splitfa = $ref_fasta;
        $ref_splitfa    =~ s/fasta$/split/;      # split fasta directory
        my $ref_dmnd    = $gdb->get_dmnd_helper(); # diamond db indexed file
        push @genome_files => { 'ref_gdb' => $gdb, 'ref_fa' => $ref_fasta, 'ref_dmnd' => $ref_dmnd, 'ref_splitfa' => $ref_splitfa };
    }
    my @sorted_genome_files = sort { $a->{ref_gdb}->dbID <=> $b->{ref_gdb}->dbID } @genome_files;
    return \@sorted_genome_files;
}

1;
