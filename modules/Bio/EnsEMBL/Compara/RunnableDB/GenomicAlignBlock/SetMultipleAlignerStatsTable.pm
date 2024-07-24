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

Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::SetMultipleAlignerStatsTable

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::SetMultipleAlignerStatsTable;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'multiplealigner_stats_table' => 'species_tree_node_tag',
    };
}


sub run {
    my $self = shift;

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();
    my $mlss_id = $self->param_required('mlss_id');
    my $mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);

    my %species_tree_gdb_id_set = map { $_->genome_db_id => 1 } @{$mlss->species_tree->root->get_all_leaves()};
    my @species_set_gdb_ids = @{$mlss->species_set->genome_dbs};

    if (grep { ! exists $species_tree_gdb_id_set{$_} } @species_set_gdb_ids) {
        $self->param('multiplealigner_stats_table', 'method_link_species_set_tag');
    }

    $self->add_or_update_pipeline_wide_parameter('multiplealigner_stats_table', $self->param('multiplealigner_stats_table'));
}


1;