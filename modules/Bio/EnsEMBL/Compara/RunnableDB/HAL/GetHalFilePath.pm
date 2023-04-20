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

Bio::EnsEMBL::Compara::RunnableDB::HAL::GetHalFilePath

=head1 DESCRIPTION

This Runnable gets the HAL file path corresponding to the given MLSS
and stores it as a pipeline-wide parameter.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::HAL::GetHalFilePath;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param_required('mlss_id');
    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adaptor->fetch_by_dbID($mlss_id);
    $self->param('hal_file_path', $mlss->url);
}


sub write_output {
    my $self = shift;

    $self->add_or_update_pipeline_wide_parameter('hal_file_path', $self->param('hal_file_path'));
}


1;
