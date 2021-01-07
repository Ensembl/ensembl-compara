=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan

=head1 DESCRIPTION

A compara runnable wrapper of Production's DataCheckFan

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DataCheckFan;

use warnings;
use strict;

use base ('Bio::EnsEMBL::DataCheck::Pipeline::DataCheckFan', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;
    $self->param('dba', $self->compara_dba);

    my $prev_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( 'compara_prev' );
    $self->param('old_server_uri', $prev_dba->url);

    $self->SUPER::fetch_input;
}

sub write_output {
    my $self = shift;

    my $datacheck = $self->param('datacheck');
    my $outfile   = $self->param('output_dir_path') . "/" . $datacheck->name . ".tap";

    $self->_spurt($outfile, $datacheck->output);

    $self->dataflow_output_id({'output_results' => $outfile}, 2);

    $self->SUPER::write_output;
}

1;
