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

Bio::EnsEMBL::Compara::PipeConfig::Protists::DumpAllForRelease_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Protists::DumpAllForRelease_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Specialized version of the DumpAllForRelease pipeline for the Protists
division. Please, refer to the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Protists::DumpAllForRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::DumpAllForRelease_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{ $self->SUPER::default_options },    # inherit the generic ones

        'dump_dir'         => $self->o('dump_root') . '/release-' . $self->o('eg_release'),

        'division'         => 'protists',

         # mlss_ids of LastZ alignments to redump
        'updated_mlss_ids' => [
            2,  # Pinf-Pram LastZ (on Pram)
            3,  # Paph-Pram LastZ (on Pram)
            4,  # Parr-Pram LastZ (on Pram)
            5,  # Pirr-Pram LastZ (on Pram)
            6,  # Piwa-Pram LastZ (on Pram)
            7,  # Pram-Pvex LastZ (on Pram)
            8,  # Pker-Pram LastZ (on Pram)
            9,  # Plat-Pram LastZ (on Pram)
            10,  # Ppar-Pram LastZ (on Pram)
            20,  # Paph-Pinf LastZ (on Pinf)
            21,  # Parr-Pinf LastZ (on Pinf)
            22,  # Pinf-Pirr LastZ (on Pinf)
            23,  # Pinf-Piwa LastZ (on Pinf)
            24,  # Pinf-Pvex LastZ (on Pinf)
            25,  # Pinf-Pker LastZ (on Pinf)
            26,  # Pinf-Plat LastZ (on Pinf)
            27,  # Pinf-Ppar LastZ (on Pinf)
            28,  # Paph-Parr LastZ (on Paph)
            29,  # Paph-Pirr LastZ (on Paph)
            30,  # Paph-Piwa LastZ (on Paph)
            31,  # Paph-Pvex LastZ (on Paph)
            32,  # Paph-Pker LastZ (on Paph)
            33,  # Paph-Plat LastZ (on Paph)
            34,  # Paph-Ppar LastZ (on Paph)
            35,  # Parr-Pirr LastZ (on Parr)
            36,  # Parr-Piwa LastZ (on Parr)
            37,  # Parr-Pvex LastZ (on Parr)
            38,  # Parr-Pker LastZ (on Parr)
            39,  # Parr-Plat LastZ (on Parr)
            40,  # Parr-Ppar LastZ (on Parr)
            41,  # Pirr-Piwa LastZ (on Pirr)
            42,  # Pirr-Pvex LastZ (on Pirr)
            43,  # Pirr-Pker LastZ (on Pirr)
            44,  # Pirr-Plat LastZ (on Pirr)
            45,  # Pirr-Ppar LastZ (on Pirr)
            46,  # Piwa-Pvex LastZ (on Piwa)
            47,  # Piwa-Pker LastZ (on Piwa)
            48,  # Piwa-Plat LastZ (on Piwa)
            49,  # Piwa-Ppar LastZ (on Piwa)
            50,  # Pker-Pvex LastZ (on Pvex)
            51,  # Plat-Pvex LastZ (on Pvex)
            52,  # Ppar-Pvex LastZ (on Pvex)
            53,  # Pker-Plat LastZ (on Pker)
            54,  # Pker-Ppar LastZ (on Pker)
            55,  # Plat-Ppar LastZ (on Plat)
            58,  # Ehis-Hara LastZ (on Hara)
            59,  # Hara-Ptri LastZ (on Hara)
            60,  # Hara-Tthe LastZ (on Hara)
            62,  # Hara-Ptet LastZ (on Hara)
            63,  # Ehux-Hara LastZ (on Hara)
            64,  # Bnat-Hara LastZ (on Hara)
            65,  # Gthe-Hara LastZ (on Hara)
            83,  # Ehis-Ptri LastZ (on Ehis)
            84,  # Ehis-Tthe LastZ (on Ehis)
            86,  # Ehis-Ptet LastZ (on Ehis)
            87,  # Ehis-Ehux LastZ (on Ehis)
            88,  # Bnat-Ehis LastZ (on Ehis)
            89,  # Ehis-Gthe LastZ (on Ehis)
            90,  # Ptri-Tthe LastZ (on Ptri)
            92,  # Ptet-Ptri LastZ (on Ptri)
            93,  # Ehux-Ptri LastZ (on Ptri)
            94,  # Bnat-Ptri LastZ (on Ptri)
            95,  # Gthe-Ptri LastZ (on Ptri)
            97,  # Ptet-Tthe LastZ (on Tthe)
            98,  # Ehux-Tthe LastZ (on Tthe)
            99,  # Bnat-Tthe LastZ (on Tthe)
            100,  # Gthe-Tthe LastZ (on Tthe)
            105,  # Ehux-Ptet LastZ (on Ptet)
            106,  # Bnat-Ptet LastZ (on Ptet)
            107,  # Gthe-Ptet LastZ (on Ptet)
            108,  # Bnat-Ehux LastZ (on Ehux)
            109,  # Ehux-Gthe LastZ (on Ehux)
            110,  # Bnat-Gthe LastZ (on Bnat)
            111,  # Hara-Pram LastZ (on Pram)
            114,  # Ehis-Pram LastZ (on Pram)
            115,  # Pram-Ptri LastZ (on Pram)
            116,  # Pram-Tthe LastZ (on Pram)
            118,  # Pram-Ptet LastZ (on Pram)
            119,  # Ehux-Pram LastZ (on Pram)
            120,  # Bnat-Pram LastZ (on Pram)
            121,  # Gthe-Pram LastZ (on Pram)
            133,  # Hara-Pinf LastZ (on Hara)
            134,  # Hara-Paph LastZ (on Hara)
            135,  # Hara-Parr LastZ (on Hara)
            136,  # Hara-Pirr LastZ (on Hara)
            137,  # Hara-Piwa LastZ (on Hara)
            138,  # Hara-Pvex LastZ (on Hara)
            139,  # Hara-Pker LastZ (on Hara)
            140,  # Hara-Plat LastZ (on Hara)
            141,  # Hara-Ppar LastZ (on Hara)
            160,  # Ehis-Pinf LastZ (on Ehis)
            161,  # Ehis-Paph LastZ (on Ehis)
            162,  # Ehis-Parr LastZ (on Ehis)
            163,  # Ehis-Pirr LastZ (on Ehis)
            164,  # Ehis-Piwa LastZ (on Ehis)
            165,  # Ehis-Pvex LastZ (on Ehis)
            166,  # Ehis-Pker LastZ (on Ehis)
            167,  # Ehis-Plat LastZ (on Ehis)
            168,  # Ehis-Ppar LastZ (on Ehis)
            169,  # Pinf-Ptri LastZ (on Ptri)
            170,  # Paph-Ptri LastZ (on Ptri)
            171,  # Parr-Ptri LastZ (on Ptri)
            172,  # Pirr-Ptri LastZ (on Ptri)
            173,  # Piwa-Ptri LastZ (on Ptri)
            174,  # Ptri-Pvex LastZ (on Ptri)
            175,  # Pker-Ptri LastZ (on Ptri)
            176,  # Plat-Ptri LastZ (on Ptri)
            177,  # Ppar-Ptri LastZ (on Ptri)
            178,  # Pinf-Tthe LastZ (on Pinf)
            180,  # Pinf-Ptet LastZ (on Pinf)
            181,  # Ehux-Pinf LastZ (on Pinf)
            182,  # Bnat-Pinf LastZ (on Pinf)
            183,  # Gthe-Pinf LastZ (on Pinf)
            184,  # Paph-Tthe LastZ (on Tthe)
            185,  # Parr-Tthe LastZ (on Tthe)
            186,  # Pirr-Tthe LastZ (on Tthe)
            187,  # Piwa-Tthe LastZ (on Tthe)
            188,  # Pvex-Tthe LastZ (on Tthe)
            189,  # Pker-Tthe LastZ (on Tthe)
            190,  # Plat-Tthe LastZ (on Tthe)
            191,  # Ppar-Tthe LastZ (on Tthe)
            200,  # Paph-Ptet LastZ (on Ptet)
            201,  # Parr-Ptet LastZ (on Ptet)
            202,  # Pirr-Ptet LastZ (on Ptet)
            203,  # Piwa-Ptet LastZ (on Ptet)
            204,  # Ptet-Pvex LastZ (on Ptet)
            205,  # Pker-Ptet LastZ (on Ptet)
            206,  # Plat-Ptet LastZ (on Ptet)
            207,  # Ppar-Ptet LastZ (on Ptet)
            208,  # Ehux-Paph LastZ (on Ehux)
            209,  # Ehux-Parr LastZ (on Ehux)
            210,  # Ehux-Pirr LastZ (on Ehux)
            211,  # Ehux-Piwa LastZ (on Ehux)
            212,  # Ehux-Pvex LastZ (on Ehux)
            213,  # Ehux-Pker LastZ (on Ehux)
            214,  # Ehux-Plat LastZ (on Ehux)
            215,  # Ehux-Ppar LastZ (on Ehux)
            216,  # Bnat-Paph LastZ (on Bnat)
            217,  # Bnat-Parr LastZ (on Bnat)
            218,  # Bnat-Pirr LastZ (on Bnat)
            219,  # Bnat-Piwa LastZ (on Bnat)
            220,  # Bnat-Pvex LastZ (on Bnat)
            221,  # Bnat-Pker LastZ (on Bnat)
            222,  # Bnat-Plat LastZ (on Bnat)
            223,  # Bnat-Ppar LastZ (on Bnat)
            224,  # Gthe-Paph LastZ (on Paph)
            225,  # Gthe-Parr LastZ (on Parr)
            226,  # Gthe-Pirr LastZ (on Pirr)
            227,  # Gthe-Piwa LastZ (on Piwa)
            228,  # Gthe-Pvex LastZ (on Pvex)
            229,  # Gthe-Pker LastZ (on Pker)
            230,  # Gthe-Plat LastZ (on Plat)
            231,  # Gthe-Ppar LastZ (on Ppar)
            232,  # Gigc-Pram LastZ (on Pram)
            234,  # Gigc-Hara LastZ (on Hara)
            237,  # Ehis-Gigc LastZ (on Ehis)
            238,  # Gigc-Ptri LastZ (on Ptri)
            239,  # Gigc-Pinf LastZ (on Pinf)
            240,  # Gigc-Tthe LastZ (on Tthe)
            241,  # Gigc-Ptet LastZ (on Ptet)
            242,  # Ehux-Gigc LastZ (on Ehux)
            243,  # Bnat-Gigc LastZ (on Bnat)
            244,  # Gigc-Paph LastZ (on Paph)
            245,  # Gigc-Parr LastZ (on Parr)
            246,  # Gigc-Pirr LastZ (on Pirr)
            247,  # Gigc-Piwa LastZ (on Piwa)
            248,  # Gigc-Pvex LastZ (on Pvex)
            249,  # Gigc-Pker LastZ (on Pker)
            250,  # Gigc-Plat LastZ (on Plat)
            251,  # Gigc-Ppar LastZ (on Ppar)
            252,  # Gigc-Gthe LastZ (on Gthe)
            253,  # Gult-Pram LastZ (on Pram)
            254,  # Gult-Hara LastZ (on Hara)
            255,  # Ehis-Gult LastZ (on Ehis)
            256,  # Gult-Ptri LastZ (on Ptri)
            257,  # Gult-Pinf LastZ (on Pinf)
            258,  # Gult-Tthe LastZ (on Tthe)
            259,  # Gult-Ptet LastZ (on Ptet)
            260,  # Ehux-Gult LastZ (on Ehux)
            261,  # Bnat-Gult LastZ (on Bnat)
            262,  # Gult-Paph LastZ (on Paph)
            263,  # Gult-Parr LastZ (on Parr)
            264,  # Gult-Pirr LastZ (on Pirr)
            265,  # Gult-Piwa LastZ (on Piwa)
            266,  # Gult-Pvex LastZ (on Pvex)
            267,  # Gult-Pker LastZ (on Pker)
            268,  # Gult-Plat LastZ (on Plat)
            269,  # Gult-Ppar LastZ (on Ppar)
            270,  # Gthe-Gult LastZ (on Gthe)
            271,  # Gigc-Gult LastZ (on Gigc)
        ],
    };
}

1;
