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

Bio::EnsEMBL::Compara::RunnableDB::EpoExtended::FindPairwiseMlssLocation

=head1 DESCRIPTION

Go through a list of databases (pairwise_location) and find where
each pairwise alignment is stored.
Will only be looking for the pairwise alignment needed to expand the
"base_method_link_species_set_id" alignment of "base_location" to
"new_method_link_species_set_id" using the reference species
"reference_species".
Stores the resulting hash in the pipeline_wide_parameters table (via a
dataflow).

=cut

package Bio::EnsEMBL::Compara::RunnableDB::EpoExtended::FindPairwiseMlssLocation;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::Utils 'stringify';
use Bio::EnsEMBL::Registry;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'dry_run' => 0,
    }
}

sub fetch_input {
    my $self = shift;

    # Transform into an array
    my $pairwise_location = $self->param_required('pairwise_location');
    $pairwise_location = [$pairwise_location] unless ref($pairwise_location);
    # If any pairwise location is a pattern (includes "*"), find all compara db
    # aliases that match that pattern and add them to 'pairwise_location'
    my @reg_aliases = @{Bio::EnsEMBL::Registry->get_all_species('compara')};
    my @db_array;
    foreach my $compara_db (@{$pairwise_location}) {
        if ($compara_db =~ s/\*/[a-zA-z0-9_]*/g) {
            push @db_array, grep { /$compara_db/ } @reg_aliases;
        } else {
            push @db_array, $compara_db;
        }
    }
    $self->param('pairwise_location', \@db_array);

    # Will hold the cache
    $self->param('dbs_loaded', {});
}

sub run {
    my $self = shift;

    my $mlss_location = $self->_find_location_of_all_required_mlss();
    $self->param('mlss_location', $mlss_location);
}

sub write_output {
    my $self = shift;

    my $mlss_location = $self->param('mlss_location');
    $self->add_or_update_pipeline_wide_parameter('pairwise_mlss_location', stringify($mlss_location));
    # give hive some time to store the param (downstram analysis was claiming it wasn't there)
    sleep(30);
}


# List the genome_db_ids for which we need an alignment
sub _find_location_of_all_required_mlss {
    my ($self) = @_;

    my $low_mlss_adaptor    = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $low_mlss            = $low_mlss_adaptor->fetch_by_dbID($self->param('new_method_link_species_set_id'));
    my $low_gdb_adaptor     = $self->compara_dba->get_GenomeDBAdaptor;
    my $low_species_tree    = $low_mlss->species_tree;
    my $low_gdb_id_2_stn    = $low_species_tree->get_genome_db_id_2_node_hash();

    my $base_dba            = $self->param('base_location') ? $self->get_cached_compara_dba('base_location') : $self->compara_dba;
    my $base_mlss_adaptor   = $base_dba->get_MethodLinkSpeciesSetAdaptor;
    my $base_mlss           = $base_mlss_adaptor->fetch_by_dbID($self->param('base_method_link_species_set_id'));
    my $base_species_tree   = $base_mlss->species_tree;
    my $base_gdb_id_2_stn   = $base_species_tree->get_genome_db_id_2_node_hash();

    my %high_coverage_genome_db_ids;
    $high_coverage_genome_db_ids{$_->dbID} = 1 for @{$base_mlss->species_set->genome_dbs};

    $self->param('base_gdb_id_2_stn', $base_gdb_id_2_stn);

    my %ss_gdb_ids = map {$_->dbID => 1} @{$low_mlss->species_set->genome_dbs};
    $self->param('genome_db_ids', \%ss_gdb_ids);

    my %mlss_location;
    foreach my $genome_db (@{$low_mlss->species_set->genome_dbs}) {
	    unless ($high_coverage_genome_db_ids{$genome_db->dbID}) {
            my ($compara_db, $mlss_id, $ref_gdb_id) = @{ $self->_find_compara_db_for_genome_db_id($genome_db->dbID) };
            print "picked mlss_id $mlss_id (ref: $ref_gdb_id) on $compara_db for " . $genome_db->name . "\n\n" if $self->debug;
            $mlss_location{$mlss_id} = $compara_db;
            
            # store species_tree_node_tag with ref_species information
            next if $self->param('dry_run');
            my $ref_gdb = $low_gdb_adaptor->fetch_by_dbID($ref_gdb_id);
            $low_gdb_id_2_stn->{$genome_db->dbID}->store_tag('reference_species', $ref_gdb->name);
	    }
    }
    return \%mlss_location;
}

# Search the alignment of a given genome_db_id in the list of compara databases
sub _find_compara_db_for_genome_db_id {
    my ($self, $genome_db_id) = @_;

    my %all_alns_for_gdb;
    foreach my $compara_db (@{$self->param('pairwise_location')}) {
        my $mlss_per_reference = $self->_load_mlss_from_compara_db($compara_db)->{$genome_db_id};
        foreach my $ref_genome_db_id ( keys %$mlss_per_reference ) {
            next unless $self->param('base_gdb_id_2_stn')->{$ref_genome_db_id}; # filter out genomes that are not in this mlss
            if ($all_alns_for_gdb{$ref_genome_db_id}) {
                print "for ref genome_db_id=$ref_genome_db_id overriding ", $all_alns_for_gdb{$ref_genome_db_id}->{compara_db}, " with $compara_db\n";
            }
            $all_alns_for_gdb{$ref_genome_db_id} = { %{$mlss_per_reference->{$ref_genome_db_id}}, compara_db => $compara_db };
        }
    }
    
    die "Could not find an alignment for genome_db_id=$genome_db_id in any of the servers: ".join(",",@{$self->param('pairwise_location')}) unless scalar(keys %all_alns_for_gdb) > 0;

    return $self->_optimal_aln_for_genome_db(\%all_alns_for_gdb, $genome_db_id);
}

# List all the alignments available in a given database
sub _load_mlss_from_compara_db {
    my ($self, $compara_db) = @_;

    return $self->param('dbs_loaded')->{$compara_db} if $self->param('dbs_loaded')->{$compara_db};

    my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($compara_db);

    my %mlss_found;
    foreach my $method_link_type (qw(LASTZ_NET BLASTZ_NET)) {
        my $some_mlsss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type($method_link_type);
        foreach my $mlss (@$some_mlsss) {
            next if $mlss->species_set->size != 2;
            my ($ref_gdb, $non_ref_gdb) = $mlss->find_pairwise_reference;
            # check if this mlss is relevant here
            next unless ( $self->param('genome_db_ids')->{$ref_gdb->dbID} && $self->param('genome_db_ids')->{$non_ref_gdb->dbID} );

            $mlss_found{$non_ref_gdb->dbID}->{$ref_gdb->dbID} = {
                mlss_id => $mlss->dbID,
                ref_cov => $mlss->get_value_for_tag('ref_genome_coverage')/$mlss->get_value_for_tag('ref_genome_length'),
            };
        }
    }

    $self->param('dbs_loaded')->{$compara_db} = \%mlss_found;
    return \%mlss_found;
}

sub _optimal_aln_for_genome_db {
    my ( $self, $all_alns_for_gdb, $non_ref_gdb_id ) = @_;
    
    my ($best_aln_mlss_id, $best_ref_gdb_id);
    my $max_coverage = 0;
    my $msa_coverage_stats = $self->_get_msa_coverage_stats($all_alns_for_gdb);
    print "mlss_id\tnon-ref_name\tref_name\tmlss_name\tlocation\tmsa_cov\tpw_cov\tcombined_cov\n" if $self->debug;
    foreach my $ref_gdb_id ( keys %$all_alns_for_gdb ) {
        my $this_mlss_id = $all_alns_for_gdb->{$ref_gdb_id}->{mlss_id};
        
        # get different types of alignment coverage
        my $msa_cov = $msa_coverage_stats->{$ref_gdb_id};
        my $pw_cov = $all_alns_for_gdb->{$ref_gdb_id}->{ref_cov};
        
        my $comb_coverage_for_ref = $msa_cov * $pw_cov;

        if ( $self->debug ) {
            my $pw_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($all_alns_for_gdb->{$ref_gdb_id}->{compara_db});
            my $gdba = $pw_dba->get_GenomeDBAdaptor;
            my $mlssa = $pw_dba->get_MethodLinkSpeciesSetAdaptor;
            my $mlss = $mlssa->fetch_by_dbID($this_mlss_id);
            my $nr_gdb = $gdba->fetch_by_dbID($non_ref_gdb_id);
            my $r_gdb = $gdba->fetch_by_dbID($ref_gdb_id);
            print $mlss->dbID . "\t" . $nr_gdb->name . "\t" . $r_gdb->name . "\t" . $mlss->name . "\t" . $all_alns_for_gdb->{$ref_gdb_id}->{compara_db} . "\t$msa_cov\t$pw_cov\t$comb_coverage_for_ref\n";
        }

        if ( $comb_coverage_for_ref > $max_coverage ) {
            $max_coverage = $comb_coverage_for_ref;
            $best_aln_mlss_id = $this_mlss_id;
            $best_ref_gdb_id = $ref_gdb_id;
        }
    }
    
    return [$all_alns_for_gdb->{$best_ref_gdb_id}->{compara_db}, $best_aln_mlss_id, $best_ref_gdb_id];
}

sub _get_msa_coverage_stats {
    my ( $self, $ref_gdbs ) = @_;

    # if all references have genome_coverage and genome_length tags in the current epo_db, then we will use that
    # otherwise, we will look for the tags in the prev_epo_db
    # finally, if all references are still not covered, we will revert to anchor_align counts

    # NOTE: all references must be covered by the same statistic or they are not comparable

    my @ref_gdb_ids = keys %$ref_gdbs;
    my $ref_count = scalar @ref_gdb_ids;

    # first try coverage from epo_db
    my $epo_db_coverage = $self->_epo_coverage($self->param('base_gdb_id_2_stn'), \@ref_gdb_ids);
    if( scalar( keys %$epo_db_coverage ) == $ref_count ) {
        print "\n-- using EPO coverage from base_location\n\n" if $self->debug;
        return $epo_db_coverage;
    }

    # next try coverage from prev_epo_db
    if ( $self->param('prev_epo_db') ) {
        my $prev_dba          = $self->get_cached_compara_dba('prev_epo_db');
        my $prev_mlss         = $prev_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type('EPO')->[0];
        my $prev_species_tree = $prev_mlss->species_tree;
        my $prev_gdb_id_2_stn = $prev_species_tree->get_genome_db_id_2_node_hash();

        my $prev_epo_db_coverage = $self->_epo_coverage($prev_gdb_id_2_stn, \@ref_gdb_ids);
        if( scalar( keys %$prev_epo_db_coverage ) == $ref_count ) {
            print "\n-- using EPO coverage from prev_epo_db\n\n" if $self->debug;
            return $prev_epo_db_coverage;
        }
    }

    # finally, try the anchor_align counts if the above have not covered all refs
    print "\n-- using anchor_align counts from base_location\n\n" if $self->debug;
    return $self->anchor_counts;
}

sub _epo_coverage {
    my ($self, $gdb_id_2_stn, $ref_gdb_ids) = @_;

    my %epo_db_coverage;
    foreach my $ref_gdb_id ( @$ref_gdb_ids ) {
        # first, get the EPO coverage for this reference species
        my $epo_stn = $gdb_id_2_stn->{$ref_gdb_id};
        next unless defined $epo_stn; # skip if the ref isn't in this epo db

        my $epo_genome_coverage = $epo_stn->get_value_for_tag('genome_coverage');
        my $epo_genome_length = $epo_stn->get_value_for_tag('genome_length');
        last unless defined $epo_genome_coverage && defined $epo_genome_length;
        $epo_db_coverage{$ref_gdb_id} = $epo_genome_coverage/$epo_genome_length;
    }

    return \%epo_db_coverage;
}

sub anchor_counts {
    my $self = shift;

    return $self->param('anchor_counts') if $self->param('anchor_counts');

    print "fetching anchor counts\n" if $self->debug;
    my $base_dba = $self->param('base_location') ? $self->get_cached_compara_dba('base_location') : $self->compara_dba;
    my $anchor_count_sql = "SELECT d.genome_db_id, COUNT(*) FROM anchor_align a JOIN dnafrag d USING(dnafrag_id) GROUP BY d.genome_db_id";
    my $anchor_counts = $base_dba->dbc->sql_helper->execute_into_hash( -SQL => $anchor_count_sql);
    $self->param('anchor_counts', $anchor_counts);
    return $anchor_counts;
}

1;
