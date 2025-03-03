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

When we build complementary gene trees we want to identify and exclude data in the overlap
between gene-tree collections, giving priority to data in higher-precedence collection(s).

This runnable identifies the genomes that are overlapping between the current collection
and its higher-precedence collection(s), and then updates the 'overlapping_genomes'
pipeline-wide parameter accordingly.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::FindOverlappingGenomes;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils qw(stringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $master_dba = $self->get_cached_compara_dba('master_db');
    my $mlss_id = $self->param_required('mlss_id');

    my $mlss = $master_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    my $mlss_info = $mlss->find_homology_mlss_sets();

    $self->add_or_update_pipeline_wide_parameter('overlapping_genomes', stringify($mlss_info->{'overlap_gdb_ids'}));
}

1;
