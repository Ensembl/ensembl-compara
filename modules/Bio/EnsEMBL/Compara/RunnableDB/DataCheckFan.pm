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
    # The pipeline may not be in the registry_file so server_uri needs to be explicitly passed
    unless ( $self->param('registry_file') ) {
        $self->param('server_uri', $self->param('compara_db'));
    }
    # For some pipelines the previous db is irrelevant so default to same db
    unless ( $self->param('old_server_uri') ) {
        my $prev_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( 'compara_prev' );
        $self->param('old_server_uri', $prev_dba->url);
    }
    $self->SUPER::fetch_input;
}

sub write_output {
    my $self = shift;

    my $datacheck = $self->param('datacheck');
    my $outfile   = $self->param('output_dir_path') . "/" . $datacheck->name . ".tap";

    die "Lost connection to MySQL server" if $datacheck->output =~ /Lost connection to MySQL server/;
    $self->_spurt($outfile, $datacheck->output);

    $self->dataflow_output_id({
        'output_results' => $outfile,
        'datacheck_type' => $datacheck->datacheck_type,
    }, 2);

    $self->SUPER::write_output;
}

1;
