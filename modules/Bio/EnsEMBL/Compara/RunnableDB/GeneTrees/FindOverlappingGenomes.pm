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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::FindOverlappingGenomes

=head1 SYNOPSIS

When we build complementary gene trees we want to identify and remove data in the overlap
between gene-tree collections, giving priority to data in the reference collection(s).

This runnable identifies the genomes that are overlapping between the current collection
and its reference collection(s), and then updates the 'overlapping_genomes' pipeline-wide
parameter accordingly.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::FindOverlappingGenomes;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::MasterDatabase;
use Bio::EnsEMBL::Hive::Utils qw(destringify stringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $master_dba = $self->get_cached_compara_dba('master_db');
    my $collection_name = $self->param_required('collection');

    my $ref_collection_names;
    if ( $self->param_is_defined('ref_collection') && $self->param_is_defined('ref_collection_list') ) {
        $self->die_no_retry("Only one of parameters 'ref_collection' or 'ref_collection_list' can be defined");
    } elsif ( $self->param_is_defined('ref_collection') ) {
        $ref_collection_names = [$self->param('ref_collection')];
    } elsif ( $self->param_is_defined('ref_collection_list') ) {
        $ref_collection_names = destringify($self->param('ref_collection_list'));
    } else {
        $self->die_no_retry("One of parameters 'ref_collection' or 'ref_collection_list' must be defined");
    }

    my $overlapping_genomes = Bio::EnsEMBL::Compara::Utils::MasterDatabase::find_overlapping_genome_db_ids($master_dba, $collection_name, $ref_collection_names);
    $self->add_or_update_pipeline_wide_parameter('overlapping_genomes', stringify($overlapping_genomes));
}

1;
