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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::RunDataChecks

=head1 DESCRIPTION

Runs an EnsEMBL Perl Datacheck (see https://github.com/Ensembl/ensembl-datacheck)
Requires several inputs:
    'output_file'      : output file in tap format (optional)
    'history_file'     : history file in json format (optional)
    'compara_db'       : db to run the HC on
    'datacheck_groups' : datacheck group type; e.g. 'compara_master' (optional)
    'failures_fatal'   : [1|0] whether datacheck is admissable or not (optional)
    'registry_file'    : compara reg_conf file with db registries
    'datacheck_types'  : [advisable|critical] (optional)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::RunDataChecks;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

    $self->param('dba', $self->compara_dba);

    $self->SUPER::fetch_input;

}

1;
