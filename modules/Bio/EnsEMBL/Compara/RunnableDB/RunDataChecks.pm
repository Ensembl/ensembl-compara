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

=cut

package Bio::EnsEMBL::Compara::RunnableDB::RunDataChecks;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::DataCheck::Pipeline::RunDataChecks', 'Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

    $self->param('dba', $self->compara_dba);

    $self->SUPER::fetch_input;

}

1;
