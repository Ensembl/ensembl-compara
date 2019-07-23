=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::FindPairwiseMlssLocation

=head1 DESCRIPTION

Go through a list of databases (pairwise_location) and find where
each pairwise alignment is stored.
Will only be looking for the pairwise alignment needed to expand the
"base_method_link_species_set_id" alignment of "base_location" to
"new_method_link_species_set_id" using the reference species
"reference_species".
Stores the resulting hash in the pipeline_wide_parameters table (via a
dataflow).

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::EpoLowCoverage::FindPairwiseMlssLocation;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::Utils 'stringify';

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    # Transform into an array
    my $pairwise_location = $self->param_required('pairwise_location');
    $self->param('pairwise_location', [$pairwise_location]) unless ref($pairwise_location);

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
    $self->dataflow_output_id({'param_name' => 'pairwise_mlss_location',
			       'param_value' => stringify($mlss_location)}, 2);
    my $refs_per_species = $self->param('refs_per_species');
    $self->dataflow_output_id({'param_name' => 'refs_per_species',
			       'param_value' => stringify($refs_per_species)}, 2);  # to pipeline_wide_parameters
}


# List the genome_db_ids for which we need an alignment
sub _find_location_of_all_required_mlss {
    my ($self) = @_;

    my $low_mlss_adaptor    = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $low_mlss            = $low_mlss_adaptor->fetch_by_dbID($self->param('new_method_link_species_set_id'));
    my $low_gdb_adaptor     = $self->compara_dba->get_GenomeDBAdaptor;
    my $low_species_tree    = $low_mlss->species_tree;
    my $low_gdb_id_2_stn    = $low_species_tree->get_genome_db_id_2_node_hash();

    my $base_dba            = $self->get_cached_compara_dba('base_location');
    my $base_mlss_adaptor   = $base_dba->get_MethodLinkSpeciesSetAdaptor;
    my $base_mlss           = $base_mlss_adaptor->fetch_by_dbID($self->param('base_method_link_species_set_id'));
    my $base_species_tree   = $base_mlss->species_tree;
    my $base_gdb_id_2_stn   = $base_species_tree->get_genome_db_id_2_node_hash();

    my %high_coverage_genome_db_ids;
    $high_coverage_genome_db_ids{$_->dbID} = 1 for @{$base_mlss->species_set->genome_dbs};

    $self->param('base_gdb_id_2_stn', $base_gdb_id_2_stn);

    my (%mlss_location, %refs_per_species);
    foreach my $genome_db (@{$low_mlss->species_set->genome_dbs}) {
	    unless ($high_coverage_genome_db_ids{$genome_db->dbID}) {
            my ($compara_db, $mlss_id, $ref_gdb_id) = @{ $self->_find_compara_db_for_genome_db_id($genome_db->dbID) };
            print "picked mlss_id $mlss_id (ref: $ref_gdb_id) for " . $genome_db->name . "\n\n" if $self->debug;
            $mlss_location{$mlss_id} = $compara_db;
            $refs_per_species{$genome_db->dbID} = $ref_gdb_id;
            
            # store species_tree_node_tag with ref_species information
            my $ref_gdb = $low_gdb_adaptor->fetch_by_dbID($ref_gdb_id);
            $low_gdb_id_2_stn->{$genome_db->dbID}->store_tag('reference_species', $ref_gdb->name);
	    }
    }
    $self->param('refs_per_species', \%refs_per_species);
    return \%mlss_location;
}

# Search the alignment of a given genome_db_id in the list of compara databases
sub _find_compara_db_for_genome_db_id {
    my ($self, $genome_db_id) = @_;

    my %all_alns_for_gdb;
    foreach my $compara_db (@{$self->param('pairwise_location')}) {
        my $mlss_per_reference = $self->_load_mlss_from_compara_db($compara_db)->{$genome_db_id};
        foreach my $ref_genome_db_id ( keys %$mlss_per_reference ) {
            $all_alns_for_gdb{$ref_genome_db_id} = { %{$mlss_per_reference->{$ref_genome_db_id}}, compara_db => $compara_db };
        }
    }
    
    die "Could not find an alignment for genome_db_id=$genome_db_id in any of the servers: ".join(",",@{$self->param('pairwise_location')}) unless defined $all_alns_for_gdb{150};

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
            next if scalar(@{$mlss->species_set->genome_dbs}) != 2;
            my ($ref_gdb, $non_ref_gdb) = $mlss->find_pairwise_reference;
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
    print "non-ref_name\tref_name\tmlss_name\tepo_cov\tlastz_cov\tcombined_cov\n";
    foreach my $ref_gdb_id ( keys %$all_alns_for_gdb ) {
        my $this_mlss_id = $all_alns_for_gdb->{$ref_gdb_id}->{mlss_id};
        
        # first, get the EPO coverage for this reference species
        my $epo_stn = $self->param('base_gdb_id_2_stn')->{$ref_gdb_id};
        next unless defined $epo_stn; # skip if the ref isn't in this epo db

        my $epo_genome_coverage = $epo_stn->get_value_for_tag('genome_coverage');
        my $epo_genome_length = $epo_stn->get_value_for_tag('genome_length');
                
        # then, get the pairwise coverage
        my $pw_cov = $all_alns_for_gdb->{$ref_gdb_id}->{ref_cov};
        
        my $comb_coverage_for_ref = ($epo_genome_coverage/$epo_genome_length) * $pw_cov;

        if ( $self->debug ) {
            my $pw_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($all_alns_for_gdb->{$ref_gdb_id}->{compara_db});
            my $gdba = $pw_dba->get_GenomeDBAdaptor;
            my $mlssa = $pw_dba->get_MethodLinkSpeciesSetAdaptor;
            my $mlss = $mlssa->fetch_by_dbID($this_mlss_id);
            my $nr_gdb = $gdba->fetch_by_dbID($non_ref_gdb_id);
            my $r_gdb = $gdba->fetch_by_dbID($ref_gdb_id);
            print $nr_gdb->name . "\t" . $r_gdb->name . "\t" . $mlss->name . "\t" . ($epo_genome_coverage/$epo_genome_length) . "\t" . $pw_cov . "\t$comb_coverage_for_ref\n";
        }

        if ( $comb_coverage_for_ref > $max_coverage ) {
            $max_coverage = $comb_coverage_for_ref;
            $best_aln_mlss_id = $this_mlss_id;
            $best_ref_gdb_id = $ref_gdb_id;
        }
    }
    
    return [$all_alns_for_gdb->{$best_ref_gdb_id}->{compara_db}, $best_aln_mlss_id, $best_ref_gdb_id];
}

1;
