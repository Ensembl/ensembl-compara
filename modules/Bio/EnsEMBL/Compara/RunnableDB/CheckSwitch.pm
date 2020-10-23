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

Bio::EnsEMBL::Compara::RunnableDB::CheckSwitch

=head1 DESCRIPTION

A small runnable to check a given parameter name and fail if
the param is 0 (false)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CheckSwitch;

use warnings;
use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub run {
    my $self = shift;
    my $switch_name = $self->param_required('switch_name');
    if( ! $self->param_required($switch_name) ) {
        die "Switch param '$switch_name' is off (0). Turn it on (1) or forgive the job to continue\n";
    }
}

1;
