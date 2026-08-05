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

Bio::EnsEMBL::Compara::RunnableDB::LoadMembers::FindNonReusedGenomeList

=cut

package Bio::EnsEMBL::Compara::RunnableDB::LoadMembers::FindNonReusedGenomeList;

use strict;
use warnings;

use File::Spec::Functions qw(catdir);
use List::Util qw(max);

use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $annotation_file;
    if($self->param_is_defined('master_db')) {

        if (!$self->param_is_defined('master_prep_db')) {
            $self->die_no_retry("Master database specified without master-prep database; both are required to find the annotation update file");
        }

        my $master_prep_dba = $self->get_cached_compara_dba('master_prep_db');

        my $hive_pipeline = Bio::EnsEMBL::Hive::HivePipeline->new(
            -no_sql_schema_version_check => 1,
            -dbconn => $master_prep_dba->dbc,
        );

        my $pipeline_param_dba = $hive_pipeline->hive_dba->get_PipelineWideParametersAdaptor();

        $annotation_file = destringify($pipeline_param_dba->fetch_all("param_name = 'annotation_file'", 'one_per_key', undef, 'param_value'));
    }

    $self->param('expected_updates_file', $annotation_file);
}


sub write_output {
    my ($self) = @_;

    my $expected_updates_file = $self->param('expected_updates_file');

    $self->dataflow_output_id({'expected_updates_file' => $expected_updates_file}, 2);
}


1;
