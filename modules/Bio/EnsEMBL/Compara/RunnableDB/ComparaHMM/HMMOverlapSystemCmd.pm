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

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMOverlapSystemCmd

=head1 DESCRIPTION

Simple wrapper around SystemCmd that sets the command using parameters
provided by HMMOverlapFactory.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMOverlapSystemCmd;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::RunnableDB::SystemCmd');

sub fetch_input {
    my $self = shift;
    my $cmd = join(' ',
        $self->param_required('python_script'),
        @{$self->param_required('script_args')},
        @{$self->param_required('input_list')},
        '>',
        $self->param_required('output_file'),
    );
    $self->param('cmd', $cmd);
}

1;
