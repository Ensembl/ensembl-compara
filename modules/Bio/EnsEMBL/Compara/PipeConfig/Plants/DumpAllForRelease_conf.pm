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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Plants::DumpAllForRelease_conf

=head1 SYNOPSIS

    init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::Plants::DumpAllForRelease_conf -host mysql-ens-compara-prod-X -port XXXX

=head1 DESCRIPTION

Specialized version of the DumpAllForRelease pipeline for the Plants
division. Please, refer to the parent class for further information.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Plants::DumpAllForRelease_conf;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::PipeConfig::DumpAllForRelease_conf');

sub default_options {
    my ($self) = @_;

    return {
        %{ $self->SUPER::default_options },    # inherit the generic ones

        'dump_dir'         => $self->o('dump_root') . '/release-' . $self->o('eg_release'),
        'ancestral_db'     => 'ancestral_curr',

        'division'          => 'plants',
        'epo_reference_species' => ['oryza_sativa'],

         # mlss_ids of LastZ alignments to redump
        'updated_mlss_ids' => [
            8760,  # Atha-Cmer lastz_net
            8773,  # Atha-Obra LastZ (on Atha)
            8882,  # Ogla-Oind lastz_net
            8890,  # Obra-Ogla lastz_net
            8898,  # Obra-Oind lastz_net
            9148,  # Atha-Osat LastZ (on Osat)
            9156,  # Cmer-Osat lastz_net
            9157,  # Alyr-Osat LastZ (on Osat)
            9160,  # Ogla-Osat LastZ (on Osat)
            9161,  # Oind-Osat LastZ (on Osat)
            9163,  # Osat-Smoe LastZ (on Osat)
            9169,  # Obra-Osat LastZ (on Osat)
            9170,  # Osat-Stub LastZ (on Osat)
            9256,  # Obar-Oniv lastz_net
            9257,  # Oglu-Oniv lastz_net
            9258,  # Oind-Oniv lastz_net
            9260,  # Ogla-Oniv lastz_net
            9261,  # Obra-Oniv lastz_net
            9262,  # Oniv-Osat LastZ (on Oniv)
            9263,  # Obar-Opun lastz_net
            9264,  # Obar-Oglu lastz_net
            9265,  # Obar-Oind lastz_net
            9267,  # Obar-Ogla lastz_net
            9268,  # Obar-Obra lastz_net
            9269,  # Obar-Osat LastZ (on Obar)
            9270,  # Oglu-Opun lastz_net
            9271,  # Oind-Opun lastz_net
            9273,  # Ogla-Opun lastz_net
            9274,  # Obra-Opun lastz_net
            9275,  # Opun-Osat LastZ (on Opun)
            9276,  # Oglu-Oind lastz_net
            9278,  # Ogla-Oglu lastz_net
            9279,  # Obra-Oglu lastz_net
            9280,  # Oglu-Osat LastZ (on Oglu)
            9283,  # Oniv-Opun lastz_net
            9303,  # Oniv-Oruf lastz_net
            9304,  # Lper-Oniv lastz_net
            9305,  # Opun-Oruf lastz_net
            9307,  # Oglu-Oruf lastz_net
            9308,  # Lper-Oglu lastz_net
            9309,  # Oind-Oruf lastz_net
            9310,  # Lper-Oind lastz_net
            9313,  # Obar-Oruf lastz_net
            9314,  # Lper-Obar lastz_net
            9315,  # Ogla-Oruf lastz_net
            9316,  # Lper-Ogla lastz_net
            9317,  # Obra-Oruf lastz_net
            9318,  # Lper-Oruf lastz_net
            9319,  # Oruf-Osat LastZ (on Osat)
            9321,  # Lper-Osat LastZ (on Osat)
            9385,  # Atha-Bole LastZ (on Atha)
            9424,  # Oglu-Omer lastz-net
            9425,  # Oglu-Olon lastz-net
            9426,  # Lper-Omer lastz-net
            9427,  # Lper-Olon lastz-net
            9428,  # Omer-Opun lastz-net
            9429,  # Omer-Oruf lastz-net
            9430,  # Oind-Omer lastz-net
            9431,  # Obra-Omer lastz-net
            9432,  # Obar-Omer lastz-net
            9433,  # Olon-Omer lastz-net
            9434,  # Omer-Osat LastZ (on Omer)
            9435,  # Omer-Oniv lastz-net
            9436,  # Ogla-Omer lastz-net
            9437,  # Olon-Opun lastz-net
            9438,  # Olon-Oruf lastz-net
            9439,  # Oind-Olon lastz-net
            9440,  # Obra-Olon lastz-net
            9441,  # Obar-Olon lastz-net
            9442,  # Olon-Osat LastZ (on Olon)
            9443,  # Olon-Oniv lastz-net
            9444,  # Ogla-Olon lastz-net
            9445,  # Atha-Olon LastZ (on Atha)
            9446,  # Atha-Omer LastZ (on Atha)
            9563,  # Alyr-Atha LastZ (on Atha)
            9566,  # Atha-Ogla LastZ (on Atha)
            9567,  # Atha-Oind LastZ (on Atha)
            9568,  # Atha-Smoe LastZ (on Atha)
            9570,  # Atha-Csat LastZ (on Atha)
            9575,  # Atha-Lang LastZ (on Atha)
            9577,  # Atha-Natt LastZ (on Atha)
            9578,  # Atha-Pvul LastZ (on Atha)
            9579,  # Atha-Pper LastZ (on Atha)
            9580,  # Atha-Sbic LastZ (on Atha)
            9582,  # Csat-Osat LastZ (on Osat)
            9587,  # Lang-Osat LastZ (on Osat)
            9589,  # Natt-Osat LastZ (on Osat)
            9590,  # Osat-Pvul LastZ (on Osat)
            9591,  # Osat-Pper LastZ (on Osat)
            9592,  # Osat-Sbic LastZ (on Osat)
            9631,  # Osat-Taes LastZ (on Taes)
            9632,  # Bdis-Taes LastZ (on Taes)
            9633,  # Taes LastZ (self-alignment)
            9634,  # Atha-Crei lastz-net
            9635,  # Atha-Ppat LastZ (on Atha)
            9637,  # Atha-Sita LastZ (on Atha)
            9639,  # Atha-Vang LastZ (on Atha)
            9640,  # Atha-Dcar LastZ (on Atha)
            9641,  # Bdis-Osat LastZ (on Osat)
            9642,  # Crei-Osat lastz-net
            9643,  # Osat-Ppat LastZ (on Osat)
            9645,  # Osat-Sita LastZ (on Osat)
            9647,  # Osat-Vang LastZ (on Osat)
            9648,  # Dcar-Osat LastZ (on Osat)
            9661,  # Atha-Bdis LastZ (on Atha)
            9663,  # Atha-Stub LastZ (on Atha)
            9666,  # Atha-Atri LastZ (on Atha)
            9667,  # Atha-Obar LastZ (on Atha)
            9668,  # Atha-Oglu LastZ (on Atha)
            9669,  # Atha-Oniv LastZ (on Atha)
            9670,  # Atha-Opun LastZ (on Atha)
            9671,  # Atha-Lper LastZ (on Atha)
            9672,  # Atha-Oruf LastZ (on Atha)
            9674,  # Atha-Bvul LastZ (on Atha)
            9675,  # Atha-Tpra LastZ (on Atha)
            9676,  # Atha-Bnap LastZ (on Atha)
            9678,  # Atha-Ccap LastZ (on Atha)
            9679,  # Atha-Taes LastZ (on Atha)
            9680,  # Atha-Vrad LastZ (on Atha)
            9681,  # Atha-Tdic LastZ (on Atha)
            9682,  # Atha-Ccri LastZ (on Atha)
            9683,  # Atha-Gsul LastZ (on Atha)
            9713,  # Atri-Osat LastZ (on Osat)
            9714,  # Bole-Osat LastZ (on Osat)
            9716,  # Bvul-Osat LastZ (on Osat)
            9717,  # Osat-Tpra LastZ (on Osat)
            9718,  # Bnap-Osat LastZ (on Osat)
            9719,  # Ccap-Osat LastZ (on Osat)
            9720,  # Osat-Vrad LastZ (on Osat)
            9721,  # Osat-Tdic LastZ (on Osat)
            9722,  # Ccri-Osat LastZ (on Osat)
            9723,  # Gsul-Osat LastZ (on Osat)
            9748,  # Ahal-Atha LastZ (on Atha)
            9749,  # Atau-Atha LastZ (on Atha)
            9750,  # Atha-Gmax LastZ (on Atha)
            9778,  # Ahal-Osat LastZ (on Osat)
            9779,  # Atau-Osat LastZ (on Osat)
            9780,  # Gmax-Osat LastZ (on Osat)
            9794,  # Bdis-Tdic LastZ (on Bdis)
            9797,  # Atau-Bdis LastZ (on Bdis)
            9809,  # Vang-Vrad LastZ (on Vrad)
            9811,  # Taes-Tdic LastZ (on Tdic)
            9812,  # Atau-Tdic LastZ (on Tdic)
            9814,  # Atau-Taes LastZ (on Taes)
            9821,  # Tdic LastZ (self-alignment)
            9823,  # Atha-Phal LastZ (on Atha)
            9824,  # Achi-Atha LastZ (on Atha)
            9829,  # Osat-Phal LastZ (on Osat)
            9830,  # Achi-Osat LastZ (on Osat)
            9846,  # Atha-Cann LastZ (on Atha)
            9847,  # Atha-Ccan LastZ (on Atha)
            9850,  # Atha-Ttur LastZ (on Atha)
            9856,  # Cann-Osat LastZ (on Osat)
            9857,  # Ccan-Osat LastZ (on Osat)
            9860,  # Osat-Ttur LastZ (on Osat)
            9861,  # Bdis-Ttur LastZ (on Bdis)
            9865,  # Atha-Ccle LastZ (on Atha)
            9867,  # Atha-Itri LastZ (on Atha)
            9873,  # Ccle-Osat LastZ (on Osat)
            9875,  # Itri-Osat LastZ (on Osat)
            9876,  # Osat-Sspo LastZ (on Osat)
            9880,  # Atau-Ttur LastZ (on Ttur)
            9881,  # Taes-Ttur LastZ (on Taes)
            9882,  # Tdic-Ttur LastZ (on Tdic)
            9884,  # Acom-Atha LastZ (on Atha)
            9887,  # Atha-Tcac LastZ (on Atha)
            9888,  # Atha-Pver LastZ (on Atha)
            9889,  # Atha-Pdul LastZ (on Atha)
            9890,  # Atha-Ecur LastZ (on Atha)
            9898,  # Acom-Osat LastZ (on Osat)
            9901,  # Osat-Tcac LastZ (on Osat)
            9902,  # Osat-Pver LastZ (on Osat)
            9903,  # Osat-Pdul LastZ (on Osat)
            9904,  # Ecur-Osat LastZ (on Osat)
            9913,  # Atha-Csfe LastZ (on Atha)
            9915,  # Atha-Cmel LastZ (on Atha)
            9916,  # Atha-Mdgo LastZ (on Atha)
            9919,  # Atha-Svir LastZ (on Atha)
            9921,  # Atha-Csat LastZ (on Atha)
            9922,  # Atha-Rchi LastZ (on Atha)
            9932,  # Atha-Clan LastZ (on Atha)
            9938,  # Aalp-Atha LastZ (on Atha)
            9965,  # Csfe-Osat LastZ (on Osat)
            9967,  # Cmel-Osat LastZ (on Osat)
            9968,  # Mdgo-Osat LastZ (on Osat)
            9971,  # Osat-Svir LastZ (on Osat)
            9973,  # Csat-Osat LastZ (on Osat)
            9974,  # Osat-Rchi LastZ (on Osat)
            9984,  # Clan-Osat LastZ (on Osat)
            9999,  # Drot-Osat LastZ (on Osat)
            10000,  # Atha-Cqui LastZ (on Atha)
            308196,  # Atha-Psom LastZ (on Atha)
            308197,  # Atha-Egra LastZ (on Atha)
            308198,  # Aoff-Osat LastZ (on Osat)
            308665,  # Taes-Tspe LastZ (on Taes)
            308668,  # Macu-Osat LastZ (on Osat)
            308669,  # Osat-Zmay LastZ (on Osat)
            309044,  # Sbic-Zmay LastZ (on Zmay)
            309045,  # Atha-Brro LastZ (on Atha)
            309050,  # Hvul-Osat LastZ (on Osat)
            309606,  # Sita-Taes LastZ (on Taes)
            309607,  # Sbic-Taes LastZ (on Taes)
            309608,  # Taes-Zmay LastZ (on Taes)
            309609,  # Bdis-Zmay LastZ (on Zmay)
            309610,  # Atha-Ccit LastZ (on Atha)
            309613,  # Osat-Tura LastZ (on Osat)
            309614,  # Osat-Scer LastZ (on Osat)
            309615,  # Taes-Tura LastZ (on Taes)
            309616,  # Taes-Tast LastZ (on Taes)
            309617,  # Taes-Tama LastZ (on Taes)
            309618,  # Taar-Taes LastZ (on Taes)
            309619,  # Taes-Tano LastZ (on Taes)
            309620,  # Taes-Taja LastZ (on Taes)
            309621,  # Scer-Taes LastZ (on Taes)
            309622,  # Taes-Tala LastZ (on Taes)
            309623,  # Taes-Taju LastZ (on Taes)
            309624,  # Taes-Tala LastZ (on Taes)
            309626,  # Hvul-Taes LastZ (on Taes)
            310222,  # Sspo-Taes LastZ (on Taes)
            310223,  # Atha-Esal LastZ (on Atha)
            310224,  # Atha-Kfed LastZ (on Atha)
            310228,  # Dexi-Osat LastZ (on Osat)
            310229,  # Ecru-Osat LastZ (on Osat)
            311031,  # Atha-Bjun LastZ (on Atha)
            311033,  # Lper-Osat LastZ (on Osat)
            311824,  # Etef-Osat LastZ (on Osat)
            313285,  # Osat-Osmh LastZ (on Osat)
            313286,  # Osat-Ospr LastZ (on Osat)
            313287,  # Osat-Osaz LastZ (on Osat)
            313288,  # Osar-Osat LastZ (on Osat)
            313289,  # Osat-Osna LastZ (on Osat)
            313290,  # Osat-Osli LastZ (on Osat)
            313291,  # Osat-Osn2 LastZ (on Osat)
            313292,  # Osat-Osla LastZ (on Osat)
            313293,  # Osat-Oskh LastZ (on Osat)
            313294,  # Osat-Oszs LastZ (on Osat)
            313295,  # Osat-Osir LastZ (on Osat)
            313296,  # Osat-Osli LastZ (on Osat)
            313297,  # Osat-Oske LastZ (on Osat)
            313298,  # Osat-Osch LastZ (on Osat)
            313299,  # Osat-Osgo LastZ (on Osat)
            313701,  # Mtru-Tpra LastZ (on Mtru)
            313702,  # Csat-Mtru LastZ (on Mtru)
            313703,  # Lang-Mtru LastZ (on Mtru)
            313704,  # Mtru-Pvul LastZ (on Mtru)
            313705,  # Mtru-Pper LastZ (on Mtru)
            313706,  # Mtru-Vang LastZ (on Mtru)
            313707,  # Mtru-Vrad LastZ (on Mtru)
            313708,  # Gmax-Mtru LastZ (on Mtru)
            313709,  # Mtru-Pavi LastZ (on Mtru)
            313710,  # Mdgo-Mtru LastZ (on Mtru)
            313711,  # Mtru-Pdul LastZ (on Mtru)
            313712,  # Cmel-Mtru LastZ (on Mtru)
            313713,  # Clan-Mtru LastZ (on Mtru)
            313714,  # Mtru-Rchi LastZ (on Mtru)
            313715,  # Csfe-Mtru LastZ (on Mtru)
            313716,  # Jreg-Mtru LastZ (on Mtru)
            313717,  # Fcar-Mtru LastZ (on Mtru)
            313718,  # Cave-Mtru LastZ (on Mtru)
            313720,  # Mtru-Psat LastZ (on Mtru)
            313721,  # Mtru-Qlob LastZ (on Mtru)
            313724,  # Mtru-Ptri LastZ (on Mtru)
            313725,  # Gsoj-Mtru LastZ (on Mtru)
            313726,  # Mtru-Vfab LastZ (on Mtru)
            313727,  # Mesc-Mtru LastZ (on Mtru)
            314076,  # Atha-Mpol LastZ (on Atha)
            314077,  # Ahyp-Mtru LastZ (on Mtru)
            314078,  # Lsat-Mtru LastZ (on Mtru)
            314079,  # Osat-Ttim LastZ (on Osat)
            314080,  # Aumb-Osat LastZ (on Osat)
            314081,  # Osat-Tspe LastZ (on Osat)
            314082,  # Taes-Tapa LastZ (on Taes)
            314083,  # Taes-Tare LastZ (on Taes)
            314084,  # Taes-Tama LastZ (on Taes)
            314085,  # Taes-Taka LastZ (on Taes)
            314086,  # Taes-Ttim LastZ (on Taes)
            314996,  # Atha-Vvin LastZ (on Atha)
            314997,  # Mtru-Sste LastZ (on Mtru)
            315367,  # Mtru-Psgc LastZ (on Mtru)
            315368,  # Lpgc-Mtru LastZ (on Mtru)
            315369,  # Mtru-Psgc LastZ (on Mtru)
            315370,  # Assa-Osat LastZ (on Osat)
            319025,  # Atha-Slgc LastZ (on Slgc)
            319026,  # Slgc-Stub LastZ (on Slgc)
            319027,  # Atha-Ncgc LastZ (on Atha)
            319028,  # Atha-Grgc LastZ (on Atha)
            320779,  # Asot-Osat LastZ (on Osat)
        ],
    };
}


sub tweak_analyses {
    my $self = shift;

    $self->SUPER::tweak_analyses(@_);

    my $analyses_by_name = shift;

    $analyses_by_name->{'md5sum_aln'}->{'-parameters'}->{'cmd'} = q/cd #output_dir# && find . -maxdepth 1 -name '*.#format#*' -printf '%f\\n' | xargs --max-args 128 md5sum > MD5SUM/;
}

1;
