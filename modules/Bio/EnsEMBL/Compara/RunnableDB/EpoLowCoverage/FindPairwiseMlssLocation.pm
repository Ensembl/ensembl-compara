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
}


# List the genome_db_ids for which we need an alignment
sub _find_location_of_all_required_mlss {
    my ($self) = @_;

    my $low_mlss_adaptor    = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $low_mlss            = $low_mlss_adaptor->fetch_by_dbID($self->param('new_method_link_species_set_id'));

    my $base_dba            = $self->get_cached_compara_dba('base_location');
    my $base_mlss_adaptor   = $base_dba->get_MethodLinkSpeciesSetAdaptor;
    my $base_mlss           = $base_mlss_adaptor->fetch_by_dbID($self->param('base_method_link_species_set_id'));

    my %high_coverage_genome_db_ids;
    $high_coverage_genome_db_ids{$_->dbID} = 1 for @{$base_mlss->species_set->genome_dbs};

    my %mlss_location;
    foreach my $genome_db (@{$low_mlss->species_set->genome_dbs}) {
	unless ($high_coverage_genome_db_ids{$genome_db->dbID}) {
            my ($compara_db, $mlss_id) = @{ $self->_find_compara_db_for_genome_db_id($genome_db->dbID) };
            #print "LASTZ found mlss " . $pairwise_mlss->dbID . "\n" if ($self->debug);
            $mlss_location{$mlss_id} = $compara_db;
	}
    }
    return \%mlss_location;
}

# Search the alignment of a given genome_db_id in the list of compara databases
sub _find_compara_db_for_genome_db_id {
    my ($self, $genome_db_id) = @_;

    foreach my $compara_db (@{$self->param('pairwise_location')}) {
        my $genome_db_ids_there = $self->_load_mlss_from_compara_db($compara_db);
        if (exists $genome_db_ids_there->{$genome_db_id}) {
            return [$compara_db, $genome_db_ids_there->{$genome_db_id}];
        }
    }

    die "Could not find an alignment for genome_db_id=$genome_db_id in any of the servers: ".join(",",@{$self->param('pairwise_location')});
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
            my $found_ref;
            my $non_ref_gdb;
            foreach my $genome_db (@{$mlss->species_set->genome_dbs}) {
                if ($genome_db->name eq $self->param('reference_species')) {
                    $found_ref = 1;
                } else {
                    $non_ref_gdb = $genome_db;
                }
            }
            if ($found_ref && $non_ref_gdb) {
                $mlss_found{$non_ref_gdb->dbID} = $mlss->dbID;
            }
        }
    }

    $self->param('dbs_loaded')->{$compara_db} = \%mlss_found;
    return \%mlss_found;
}


1;
