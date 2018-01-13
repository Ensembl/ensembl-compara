=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Lastz_conf;


use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::PipeConfig::Lastz_conf');  # Inherit from base PairAligner class


sub default_options {
    my ($self) = @_;
    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        #Location of executables
        'pair_aligner_exe'  => $self->check_exe_in_cellar('lastz/1.04.00/bin/lastz'),
        'faToNib_exe'       => $self->check_exe_in_cellar('kent/v335_1/bin/faToNib'),
        'lavToAxt_exe'      => $self->check_exe_in_cellar('kent/v335_1/bin/lavToAxt'),
        'axtChain_exe'      => $self->check_exe_in_cellar('kent/v335_1/bin/axtChain'),
        'chainNet_exe'      => $self->check_exe_in_cellar('kent/v335_1/bin/chainNet'),

    };
}

sub resource_classes {
    my ($self) = @_;

    return {
            %{$self->SUPER::resource_classes},  # inherit 'default' from the parent class
            '100Mb'       => { 'LSF' => '-C0 -M100 -R"select[mem>100] rusage[mem=100]"' },
            '1Gb'         => { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
            'long'        => { 'LSF' => '-C0 -M1000 -R"select[mem>1000] rusage[mem=1000]"' },
            'crowd'       => { 'LSF' => '-C0 -M1800 -R"select[mem>1800] rusage[mem=1800]"' },
            'crowd_himem' => { 'LSF' => '-C0 -M6000 -R"select[mem>6000] rusage[mem=6000]"' },
    };
}

1;
