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

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_).

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::DetectComponentMLSSs;

use warnings;
use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    my $net_mlss_ids = $self->param_required('net_mlss_ids');
    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor();

    my %mlsss;
    foreach my $mlss_id ( @{$net_mlss_ids} ) {
        my $this_mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);
        my $principal_mlss_id = $this_mlss->get_tagvalue('principal_mlss_id');
        if (defined $principal_mlss_id) {
            push @{$mlsss{$principal_mlss_id}}, $mlss_id;
        } else {
            push @{$mlsss{$mlss_id}}, $mlss_id;
        }
    }
    $self->param('mlsss', \%mlsss);

    my @hc_tests;
    push @hc_tests, 'pairwise_gabs' if $self->param('do_pairwise_gabs');
    push @hc_tests, 'compare_to_previous_db' if $self->param('do_compare_to_previous_db');
    $self->param('hc_tests', \@hc_tests);
}


sub write_output {
    my $self = shift;
    
    my $mlsss    = $self->param('mlsss');
    my $hc_tests = $self->param('hc_tests');

    my $column_names = ['mlss_id', 'test'];
    my @input_list;
    push @input_list, ['#mlss_id#', $_] for @{$hc_tests};

    foreach my $mlss_id ( keys %{$mlsss} ) {
        # The principal MLSS id will not be part of the MLSS ids array
        $self->dataflow_output_id(
            {'principal_mlss_id' => $mlss_id, 'component_mlss_ids' => $mlsss->{$mlss_id}},
            3
        ) if ($mlsss->{$mlss_id}->[0] != $mlss_id);
        $self->dataflow_output_id(
            {'mlss_id' => $mlss_id, 'inputlist' => \@input_list, 'column_names' => $column_names},
            2
        );
    }
}


1;
