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

Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::CopyAncestralData

=head1 DESCRIPTION

Runs the $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/copy_ancestral_core.pl
script, dealing with missing parameters.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::UpdateMSA::CopyAncestralData;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');


sub fetch_input {
    my $self = shift;

    if ( $self->param('from_url') && $self->param('from_dbc') ) {
        $self->throw("Expected 'from_url' or 'from_dbc', not both!");
    }
    if ( $self->param('to_url') && $self->param('to_dbc') ) {
        $self->throw("Expected 'to_url' or 'to_dbc', not both!");
    }

    my @cmd;
    push @cmd, $self->param_required('program');
    push @cmd, '--reg_conf', $self->param('reg_conf') if $self->param('reg_conf');
    push @cmd, '--from_url', $self->param('from_url') if $self->param('from_url');
    push @cmd, '--from_url', Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($self->param('from_dbc'))->url if $self->param('from_dbc');
    push @cmd, '--from', $self->param('from_name') if $self->param('from_name');
    push @cmd, '--to_url', $self->param('to_url') if $self->param('to_url');
    push @cmd, '--to_url', Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($self->param('to_dbc'))->url if $self->param('to_dbc');
    push @cmd, '--to', $self->param('to_name') if $self->param('to_name');
    push @cmd, '--mlss_id', $self->param('msa_mlss_id') if $self->param('msa_mlss_id');

    $self->param('cmd', \@cmd);
}


1;
