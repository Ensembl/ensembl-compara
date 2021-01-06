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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DetectComponentMLSSs

=head1 DESCRIPTION

Detect component MLSSs (those with mlss_tag "principal_mlss_id") and group them
to lift their genomic_aligns and genomic_align_blocks to the corresponding
principal MLSS.

=over

=item net_mlss_ids

Mandatory. List of LASTZ_NET MLSS ids.

=item do_pairwise_gabs

Optional. Perform "pairwise genomic_align_blocks" healthcheck on the principal
MLSS after the data has been lifted?

=item do_compare_to_previous_db

Optional. Perform "compare to previous DB" healthcheck on the principal MLSS
after the data has been lifted?

=back

=head1 EXAMPLES

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DetectComponentMLSSs \
        -compara_db $(mysql-ens-compara-prod-8-ensadmin details url jalvarez_shoots_lastz) \
        -net_mlss_ids [5,6] -do_pairwise_gabs 1

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DetectComponentMLSSs;

use warnings;
use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub write_output {
    my $self = shift;

    my $net_mlss_ids = $self->param_required('net_mlss_ids');
    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();

    my @hc_tests;
    push @hc_tests, 'pairwise_gabs' if $self->param('do_pairwise_gabs');
    push @hc_tests, 'compare_to_previous_db' if $self->param('do_compare_to_previous_db');

    my $column_names = ['mlss_id', 'test'];
    my @input_list = map { ['#mlss_id#', $_] } @hc_tests;

    foreach my $main_mlss_id ( @{$net_mlss_ids} ) {
        my $mlss = $mlss_adaptor->fetch_by_dbID($main_mlss_id);
        if ($mlss->get_value_for_tag('is_for_polyploids')) {
            $self->dataflow_output_id({
                'principal_mlss_id'  => $main_mlss_id,
            }, 3);
        }
        $self->dataflow_output_id(
            {'mlss_id' => $main_mlss_id, 'inputlist' => \@input_list, 'column_names' => $column_names},
            2
        );
    }
}


1;
