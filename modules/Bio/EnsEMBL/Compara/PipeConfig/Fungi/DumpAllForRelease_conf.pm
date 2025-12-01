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

Bio::EnsEMBL::Compara::PipeConfig::Fungi::DumpAllForRelease_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Fungi::DumpAllForRelease_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Specialized version of the DumpAllForRelease pipeline for the Fungi
division. Please, refer to the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Fungi::DumpAllForRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::DumpAllForRelease_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{ $self->SUPER::default_options },  # inherit the generic ones

        'dump_dir'          => $self->o('dump_root') . '/release-' . $self->o('eg_release'),

        'division'          => 'fungi',

         # mlss_ids of LastZ alignments to redump
        'updated_mlss_ids' => [
            8639,  # Foxy-Fver LastZ (on Foxy)
            8642,  # Foxy-Fsol LastZ (on Foxy)
            8644,  # Fsol-Fver LastZ (on Fsol)
            9217,  # Scry-Spom LastZ (on Scry)
            9218,  # Scry-Soct LastZ (on Scry)
            9219,  # Scry-Sjap LastZ (on Scry)
            9220,  # Soct-Spom LastZ (on Soct)
            9221,  # Sjap-Spom LastZ (on Sjap)
            9222,  # Sjap-Soct LastZ (on Sjap)
            9360,  # Foxy-Mpoa LastZ (on Foxy)
            9361,  # Foxy-Pgra LastZ (on Foxy)
            9363,  # Foxy-Scer LastZ (on Foxy)
            9364,  # Foxy-Scry LastZ (on Foxy)
            9365,  # Foxy-Sjap LastZ (on Foxy)
            9366,  # Foxy-Soct LastZ (on Foxy)
            9367,  # Foxy-Spom LastZ (on Foxy)
            9368,  # Foxy-Tvir LastZ (on Foxy)
            9370,  # Fsol-Mpoa LastZ (on Fsol)
            9371,  # Fsol-Pgra LastZ (on Fsol)
            9373,  # Fsol-Scer LastZ (on Fsol)
            9374,  # Fsol-Scry LastZ (on Fsol)
            9375,  # Fsol-Sjap LastZ (on Fsol)
            9376,  # Fsol-Soct LastZ (on Fsol)
            9377,  # Fsol-Spom LastZ (on Fsol)
            9378,  # Fsol-Tvir LastZ (on Fsol)
            9380,  # Fver-Mpoa LastZ (on Fver)
            9381,  # Fver-Pgra LastZ (on Fver)
            9383,  # Fver-Scer LastZ (on Fver)
            9384,  # Fver-Scry LastZ (on Fver)
            9385,  # Fver-Sjap LastZ (on Fver)
            9386,  # Fver-Soct LastZ (on Fver)
            9387,  # Fver-Spom LastZ (on Fver)
            9388,  # Fver-Tvir LastZ (on Fver)
            9397,  # Mpoa-Pgra LastZ (on Mpoa)
            9399,  # Mpoa-Scer LastZ (on Mpoa)
            9400,  # Mpoa-Scry LastZ (on Mpoa)
            9401,  # Mpoa-Sjap LastZ (on Mpoa)
            9402,  # Mpoa-Soct LastZ (on Mpoa)
            9403,  # Mpoa-Spom LastZ (on Mpoa)
            9404,  # Mpoa-Tvir LastZ (on Mpoa)
            9405,  # Pgra-Scer LastZ (on Pgra)
            9406,  # Pgra-Scry LastZ (on Pgra)
            9407,  # Pgra-Sjap LastZ (on Pgra)
            9408,  # Pgra-Soct LastZ (on Pgra)
            9409,  # Pgra-Spom LastZ (on Pgra)
            9410,  # Pgra-Tvir LastZ (on Pgra)
            9417,  # Scer-Scry LastZ (on Scer)
            9418,  # Scer-Sjap LastZ (on Scer)
            9419,  # Scer-Soct LastZ (on Scer)
            9420,  # Scer-Spom LastZ (on Scer)
            9421,  # Scer-Tvir LastZ (on Scer)
            9422,  # Scry-Tvir LastZ (on Scry)
            9423,  # Sjap-Tvir LastZ (on Sjap)
            9424,  # Soct-Tvir LastZ (on Soct)
            9425,  # Spom-Tvir LastZ (on Spom)
            9427,  # Foxy-Ptri LastZ (on Foxy)
            9428,  # Fsol-Ptri LastZ (on Fsol)
            9429,  # Fver-Ptri LastZ (on Fver)
            9431,  # Mpoa-Ptri LastZ (on Mpoa)
            9432,  # Pgra-Ptri LastZ (on Pgra)
            9433,  # Ptri-Scer LastZ (on Scer)
            9434,  # Ptri-Scry LastZ (on Scry)
            9435,  # Ptri-Sjap LastZ (on Sjap)
            9436,  # Ptri-Soct LastZ (on Soct)
            9437,  # Ptri-Spom LastZ (on Spom)
            9438,  # Ptri-Tvir LastZ (on Tvir)
            9439,  # Egfg-Foxy LastZ (on Egfg)
            9440,  # Egfg-Fsol LastZ (on Egfg)
            9441,  # Egfg-Fver LastZ (on Egfg)
            9442,  # Egfg-Mpoa LastZ (on Egfg)
            9443,  # Egfg-Pgra LastZ (on Egfg)
            9444,  # Egfg-Scer LastZ (on Egfg)
            9445,  # Egfg-Scry LastZ (on Egfg)
            9446,  # Egfg-Sjap LastZ (on Egfg)
            9447,  # Egfg-Soct LastZ (on Egfg)
            9448,  # Egfg-Spom LastZ (on Egfg)
            9449,  # Egfg-Tvir LastZ (on Egfg)
            9450,  # Egfg-Pory LastZ (on Egfg)
            9451,  # Egfg-Ptri LastZ (on Egfg)
            9452,  # Foxy-Pory LastZ (on Foxy)
            9453,  # Fsol-Pory LastZ (on Fsol)
            9454,  # Fver-Pory LastZ (on Fver)
            9455,  # Mpoa-Pory LastZ (on Mpoa)
            9456,  # Pgra-Pory LastZ (on Pgra)
            9457,  # Pory-Scer LastZ (on Scer)
            9458,  # Pory-Scry LastZ (on Scry)
            9459,  # Pory-Sjap LastZ (on Sjap)
            9460,  # Pory-Soct LastZ (on Soct)
            9461,  # Pory-Spom LastZ (on Spom)
            9462,  # Pory-Tvir LastZ (on Tvir)
            9463,  # Pory-Ptri LastZ (on Pory)
        ],
    };
}

1;
