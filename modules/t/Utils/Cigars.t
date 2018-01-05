#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;
 
use Test::More tests => 9;
use Test::Exception;

use Bio::EnsEMBL::Compara::Utils::Cigars;

subtest 'compose_sequence_with_cigar' => sub {
    is( Bio::EnsEMBL::Compara::Utils::Cigars::compose_sequence_with_cigar('abcde', 'M2D3MDM'), 'a--bcd-e');
    is( Bio::EnsEMBL::Compara::Utils::Cigars::compose_sequence_with_cigar('abcde', 'M2D3MDM', 0), 'a--bcd-e');
    is( Bio::EnsEMBL::Compara::Utils::Cigars::compose_sequence_with_cigar('abcde', 'M2D3MDM', 1), 'a--bcd-e');
    is( Bio::EnsEMBL::Compara::Utils::Cigars::compose_sequence_with_cigar('abcde', 'M2D3MDM', 2), 'ab----cdeNNN--NN');
    is( Bio::EnsEMBL::Compara::Utils::Cigars::compose_sequence_with_cigar('aabbccddee', 'M2D3MDM', 2), 'aa----bbccdd--ee');
    throws_ok {Bio::EnsEMBL::Compara::Utils::Cigars::compose_sequence_with_cigar('aabbccddee', 'y*7')} qr/Invalid cigar_line/, 'Invalid cigar-line';
    throws_ok {Bio::EnsEMBL::Compara::Utils::Cigars::compose_sequence_with_cigar('aabbccddee', '7Y')} qr/'Y' characters in cigar lines are not currently handled/, 'Invalid character in cigar-line';
    is( Bio::EnsEMBL::Compara::Utils::Cigars::compose_sequence_with_cigar('abcde', 'M2D3IDM'), 'a---e');
    is( Bio::EnsEMBL::Compara::Utils::Cigars::compose_sequence_with_cigar('abc de', 'M2D3MDM'), 'a--bc d-e');
};

subtest 'cigar_from_alignment_string' => sub {
    is( Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_alignment_string('a--bcd-e'), 'M2D3MDM');
    is( Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_alignment_string('a--bcd.e'), 'M2D3MXM');
};

sub try_one_dataset {
    plan tests => 4;

    my ($cig, $aln) = @_;
    my $seq = $aln;
    $seq =~ s/-//g;

    is( Bio::EnsEMBL::Compara::Utils::Cigars::compose_sequence_with_cigar($seq, $cig), $aln, 'compose_sequence_with_cigar($seq, $cig)' );
    is( Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_alignment_string($aln), $cig, 'cigar_from_alignment_string($aln)' );

    my $exp_cigar = Bio::EnsEMBL::Compara::Utils::Cigars::expand_cigar($cig);
    is( length($exp_cigar), length($aln), 'expand_cigar($cig)' );

    is( Bio::EnsEMBL::Compara::Utils::Cigars::collapse_cigar($exp_cigar), $cig, 'collapse_cigar(expand_cigar($cig))' );
}

my $cig = '209DM2D5MD8M8D13M79D10M18D3M12D21M3D4M3D17MD8M8DM5D12M3D2M42D2M9D13M18D2MD6M12D7M4D18M3D10M4D4M3D4M6D6M3DMD10M3D2M3DMD3M9D5MD6M2D15M2D8MD9M2D4MD8M6D14MD8MD5MD2M13D32M253D5MDM2D9M3D5M5D17M2D2M47DMD4M6D5M2D18M3D6M9D7MD13M3D4MDM23D9M2D15M2D4M2D8M3D2M7D10M75D3M10D5M10D6MD2M4D15M2D6M3D14M2DM8D7M2D3MD2M10DM2D4M3DM4D9MD12MD5M25D4MD2M13DM184D13M78D3M51D3M5D7M131D7M2DMDM12D3MD2M2D10M20D25MD3M5D2M3D5M125D23MD8M6D9M992D2MDM93D2M18D9M21D36M24D4MD14M7D2M7D5M2D19M123D';
my $aln = '-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------M--ELRPW-LQWTVVAA--------LILLVGEVLTQKV-------------------------------------------------------------------------------YTNTWAVFIP------------------GGL------------TEANKVAQKHGFLNLGPIFGD---YYHF---WHRAVVKRSLSPHRPRH-SRLQREPK--------V-----QWLEQQVAKRRK---KR------------------------------------------DI---------FMEPTDPKFPQQW------------------YL-YGTNQR------------DLNVRGA----WSQGYTGRGIVVSILDDG---IEKNHPDLEG----NYDP---GASF------DVNDQD---P-DPQPRYTQMN---DN---R-HGT---------RCAGE-VAAVAN--NGICGVGVAYNARIG--GVRMLDGE-VTDAVEARS--LGLN-PNHIHIYS------ASWGPEDDGKTVDG-PARLAEEA-FSRGV-NQ-------------GRGGLGSIFVWASGNGGREHDSCNCDGYTNSI-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------YTLSI-S--STTQFGNVP---WYSEA-----CSSTLATTYSSGNQNEK--QI-----------------------------------------------V-TTDL------RQKCT--DSHTGTSASAPLAAGIIA---LTLEAN---------KNLTWRD-MQHLVVQTSKPAH---LNAN-D-----------------------WTTNGVGRR--VSHSYGYGLLDAGAM--VALA--RNWTTVGP---QR-------KCLIDILTEP---------------------------------------------------------------------------TDI----------GKRLE----------VRRKVT-AC----QGEVNHITRLEHAQA--RLTLSY---NRRGDLAIYLVSPM--G--------TRSTLLA--SXX-XX----------X--XXXX---X----XXWAFMTTH-SWDEDPAGDWVL-EIENT-------------------------SEAN-NY-------------G----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------TLTKFTLVLYGTA------------------------------------------------------------------------------SEE---------------------------------------------------PDL-----STPSESI-----------------------------------------------------------------------------------------------------------------------------------GCKTLAS--S-Q------------TCV-VC--EEGFSLHQKN--------------------CVRHCPQGFISQVVNTQYSIENDME-SIH-----AN---VCSPC-----------------------------------------------------------------------------------------------------------------------------HPSCATCKGIESTDCLSCPIFSD-YDLVELTC------TQQRQASFK--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------SQ-L---------------------------------------------------------------------------------------------PQ------------------RGLLPSHLP---------------------VVVAGLSCAFIVLVFIIVFLILQLRSGFSFRGVKVY------------------------SLDS-GIISYKGLPPDAWQ-------EE-------CPSES--DEDEVRGERTAFIKDQSAL---------------------------------------------------------------------------------------------------------------------------';

subtest 'Short cigar' => sub {
    try_one_dataset('2MD3M2D2M', 'AA-CGC--TT');
};

subtest 'Long cigar' => sub {
    try_one_dataset($cig, $aln);
};

subtest 'Combined cigars' => sub {
    plan tests => 5;
    my $aln_seq1 = 'SRRILKGDQGQDGAAGPPGP---PGPPGARGPPGDTGKDGPRGPQGLPGLKGEPGEAGVMGVRGPSGLKGEPGFPGRKGDDGTPGQPGLQGPKGEQGSTGPKGEKGLDGLPGSKGDPGERGGDGPIGPRGPPGLKGEQGDTVIIDYDGRILDALKVR----------****FVLYLYSFVLL*GELGLPGTPGVDGEKGSKGDPGNPGIMGQKGEIGEMGLSGLPGIDGPKGEKGETGSPCLQNNH-------IIPEPGPPGLPGPMGPQGI---PGPKGLDGVKGEKGDHGEKGATGDTGPPGP------------AGPPGLIGLPGTKGEKGKPGEPGLDGFPGLRGEKGDK------SERGEKGERGIPGRKGAKGQKGEPGPPG';
    my $aln_seq2 = 'ARMALKGPPGPMGFTGRPGPLGNPGSPGLKGESGDPGSQGPRGPQ---GLLGPPGKSGRRGRAGADGARGMPGETGSKGDRGFDGLPGLPGDKGHRGDPGPM------GLQGSTGEDGERGDDGDVGPRGLPGEPGPRG-LLGPKGPPGISGPPGVRGNDGPHGPKG-----NLGPQGEPGPPGQQGTPGTQGMPGPQGAIGPP------GEKGPTGKPGLPGMPGADGPPGHPGKEGPSGTKGNQGPNGPQGAIGYPGPRGIKGAQGIRGLKGHKGEKGEDGFPGIKGDFGVKGERGEIGVPGPRGEDGPEGPKGRVGPPGELGTIGLAGEKGKLGVPGLPGYPGRQGIKGSLGFPGFPGSNGEKGTRGVTGKQGPRGQRGPTGPRG';
    my $cig12 = "20M3D22M3I54M6I31MI17M10D5I32M6I36M7D19M3D30M12D37M6D28M";
    my $cig21 = $cig12;
    $cig21 =~ tr/DI/ID/;

    is( Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_two_alignment_strings($aln_seq1, $aln_seq2), $cig12, 'cigar_from_two_alignment_strings($aln_seq1, $aln_seq2)' );
    is( Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_two_alignment_strings($aln_seq2, $aln_seq1), $cig21, 'cigar_from_two_alignment_strings($aln_seq2, $aln_seq1)' );
    throws_ok {Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_two_alignment_strings('M-', 'M-')} qr/Double gaps are not allowed/, 'Double gaps are not allowed';
    throws_ok {Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_two_alignment_strings('MK', 'M')} qr/lengths do not match/, 'lengths do not match';
    throws_ok {Bio::EnsEMBL::Compara::Utils::Cigars::cigar_from_two_alignment_strings('M', 'MK')} qr/lengths do not match/, 'lengths do not match';
};

subtest 'Minimized cigars' => sub {
    plan tests => 1;
    my $cig1 = '209DM2D5MD8M8D13M79D10M18D3M12D21M3D4M3D17MD8M8DM5D12M3D2M42D2M9D13M18D2MD6M12D7M4D18M3D10M4D4M3D4M6D6M3DMD10M3D2M3DMD3M9D5MD6M2D15M2D8MD9M2D4MD8M6D14MD8MD5MD2M13D32M253D5MDM2D9M3D5M5D17M2D2M47DMD4M6D5M2D18M3D6M9D7MD13M3D4MDM23D9M2D15M2D4M2D8M3D2M7D10M75D3M10D5M10D6MD2M4D15M2D6M3D14M2DM8D7M2D3MD2M10DM2D4M3DM4D9MD12MD5M25D4MD2M13DM184D13M78D3M51D3M5D7M131D7M2DMDM12D3MD2M2D10M20D25MD3M5D2M3D5M125D23MD8M6D9M992D2MDM93D2M18D9M21D36M24D4MD14M7D2M7D5M2D19M123D';
    my $cig2 = '382D9MD5M8D12MD17M5D12M3D2M53D13M18D10M11D7M4D18M3D10M4D4M3D4M6D6M3DMD10M3D2M3DMD3M9D5MD6M2D15M2D8MD9M2D4MD8M6D14MD8MD5MD2M13D32M253D5MDM2D9M3D5M5D17M2D2M47DMD11M2D2M2D18M3D6M9D7MD13M3D4MDM23D9M2D15M2D4M2D8M3D2M7D10M75D3M3DM4D7M10D6M5D17M2D6M3D14M2DM8D7M2D3MD2M10DM2D4M3DM4D9MD12MD4M38DM2D8M182D13M310D10M3D12M2D25M1334D37MD3MD9M2D50MD12M2D2MD4M3D5M110D';

    my $reduced1 = '61M2D29M8D32MD6MD226M6D105M3D13M2D86M6DM2D50M15D125M20D4MD14M7D2M7D5M2D19M9D';
    my $reduced2 = '53D14M5D43M2D256M2D116M2D81M7D22M27D47M68D99MD12M2D11M';

    is_deeply( [Bio::EnsEMBL::Compara::Utils::Cigars::minimize_cigars($cig1, $cig2)], [$reduced1, $reduced2], 'minimize_cigars($cig1, $cig2)');
};


subtest 'Removed columns' => sub {
    plan tests => 6;

    my $aln1 = 'OQQQWE--YUBIAOP';
    my $aln2 = 'OQQQ-ERTY-NIAO-';

    my $fil1 = 'QQQWEYUBIO';
    my $fil2 = 'QQQ-EY-NIO';

    my $rema = '[0,0],[6,7],[12,12],[14,14]';

    is( Bio::EnsEMBL::Compara::Utils::Cigars::identify_removed_columns({'1' => $aln1, '2' => $aln2}, {'1' => $fil1, '2' => $fil2}), $rema, 'identify_removed_columns($data)');

    my $fil1_wrong = 'QQQWEYUCIO';
    throws_ok {Bio::EnsEMBL::Compara::Utils::Cigars::identify_removed_columns({'1' => $aln1, '2' => $aln2}, {'1' => $fil1_wrong, '2' => $fil2})} qr/Could not match alignments/, 'Could not match alignments';

    my $aln13 = 'OooQqqQqqQqqWwwEee------YyyUuuBbbIiiAaaOooPpp';
    my $aln23 = 'OooQqqQqqQqq---EeeRrrTttYyy---NnnIiiAaaOoo---';

    my $fil13 = 'QqqQqqQqqWwwEeeYyyUuuBbbIiiOoo';
    my $fil23 = 'QqqQqqQqq---EeeYyy---NnnIiiOoo';

    my $remb = '[0,0],[6,7],[12,12],[14,14]';

    is( Bio::EnsEMBL::Compara::Utils::Cigars::identify_removed_columns({'1' => $aln13, '2' => $aln23}, {'1' => $fil13, '2' => $fil23}, 3), $remb, 'identify_removed_columns($data3, 3)');

    throws_ok {Bio::EnsEMBL::Compara::Utils::Cigars::identify_removed_columns({'1' => $aln1}, {})} qr/The number of sequences do not match/, 'The number of sequences do not match';

    my $aln1s = 'OQQQ';
    my $aln2s = 'OQQQ';

    my $fil1s = 'QQQ';
    my $fil2s = 'QQQ';

    my $remas = '[0,0]';

    is( Bio::EnsEMBL::Compara::Utils::Cigars::identify_removed_columns({'1' => $aln1s, '2' => $aln2s}, {'1' => $fil1s, '2' => $fil2s}), $remas, 'identify_removed_columns($data)');

    # TreeBest can add some Ns
    my $aln1n = 'OQ-Q';
    my $aln2n = 'OR-Q';

    my $fil1n = 'QN';
    my $fil2n = 'RQ';

    my $reman = '[0,0],[2,2]';

    is( Bio::EnsEMBL::Compara::Utils::Cigars::identify_removed_columns({'1' => $aln1n, '2' => $aln2n}, {'1' => $fil1n, '2' => $fil2n}), $reman, 'identify_removed_columns($data)');
};

subtest 'Consensus cigar' => sub {
    plan tests => 2;
    my $cig1 = '209DM2D5MD8M8D13M79D10M18D3M12D21M3D4M3D17MD8M8DM5D12M3D2M42D2M9D13M18D2MD6M12D7M4D18M3D10M4D4M3D4M6D6M3DMD10M3D2M3DMD3M9D5MD6M2D15M2D8MD9M2D4MD8M6D14MD8MD5MD2M13D32M253D5MDM2D9M3D5M5D17M2D2M47DMD4M6D5M2D18M3D6M9D7MD13M3D4MDM23D9M2D15M2D4M2D8M3D2M7D10M75D3M10D5M10D6MD2M4D15M2D6M3D14M2DM8D7M2D3MD2M10DM2D4M3DM4D9MD12MD5M25D4MD2M13DM184D13M78D3M51D3M5D7M131D7M2DMDM12D3MD2M2D10M20D25MD3M5D2M3D5M125D23MD8M6D9M992D2MDM93D2M18D9M21D36M24D4MD14M7D2M7D5M2D19M123D';
    my $cig2 = '382D9MD5M8D12MD17M5D12M3D2M53D13M18D10M11D7M4D18M3D10M4D4M3D4M6D6M3DMD10M3D2M3DMD3M9D5MD6M2D15M2D8MD9M2D4MD8M6D14MD8MD5MD2M13D32M253D5MDM2D9M3D5M5D17M2D2M47DMD11M2D2M2D18M3D6M9D7MD13M3D4MDM23D9M2D15M2D4M2D8M3D2M7D10M75D3M3DM4D7M10D6M5D17M2D6M3D14M2DM8D7M2D3MD2M10DM2D4M3DM4D9MD12MD4M38DM2D8M182D13M310D10M3D12M2D25M1334D37MD3MD9M2D50MD12M2D2MD4M3D5M110D';
    my $consensus = '209Dm2D5mD8m8D13m79D10m18D3m12D13m8MmDm4M3D5m12MD8M8mM5D12M3D2M42D2m9D13M18D2Mm6Mm11D7M4D18M3D10M4D4M3D4M6D6M3DMD10M3D2M3DMD3M9D5MD6M2D15M2D8MD9M2D4MD8M6D14MD8MD5MD2M13D32M253D5MDM2D9M3D5M5D17M2D2M47DMD4M6mM2m2M2D18M3D6M9D7MD13M3D4MDM23D9M2D15M2D4M2D8M3D2M7D10M75D3M3Dm4D2m5M10D6MD2m2D2m15M2D6M3D14M2DM8D7M2D3MD2M10DM2D4M3DM4D9MD12MD4Mm25D4mD2m5Dm2D5mM2m182D13M78D3m51D3m5D7m131D7m2DmDm12D3mD2m2D10M3D12m2D3m22M3mD3m5D2m3D5m125D23mD8m6D9m992D2mDm93D2m18D9m21Dm35M2mD3mD9m2D6m4Mm14M7m2M7m5M2m2Mm12M2m2MD4m3D5m110D';

    is( Bio::EnsEMBL::Compara::Utils::Cigars::consensus_cigar_line($cig1, $cig2), $consensus, 'consensus_cigar_line($cig1, $cig2)');
    throws_ok {Bio::EnsEMBL::Compara::Utils::Cigars::consensus_cigar_line($cig1, substr($cig2, 4))} qr/Not all the cigars have the same length/, 'Inconsistent cigar lengths';
};

subtest 'Breakout counts' => sub {

    my $cig1 = 'M2D3MDX';
    my %count1 = ('M' => 4, 'D' => 3, 'X' => 1);
    is_deeply( {Bio::EnsEMBL::Compara::Utils::Cigars::get_cigar_breakout($cig1)}, \%count1, $cig1);
};


done_testing();
