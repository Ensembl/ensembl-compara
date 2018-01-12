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

use Test::More;
use Test::Exception;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils qw(debug test_getter_setter);

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');

my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");

my $hs_dba = $homo_sapiens->get_DBAdaptor('core');
my $mm_dba = $mus_musculus->get_DBAdaptor('core');
my $compara_dba = $multi->get_DBAdaptor('compara');

my $human_name     = "homo_sapiens";
my $human_assembly = $hs_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;
my $mouse_name       = "mus_musculus";
my $mouse_assembly   = $mm_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;

my $gdba = $compara_dba->get_GenomeDBAdaptor;

#my $hs_gdb = $gdba->fetch_by_name_assembly($human_name,$human_assembly);
#$hs_gdb->db_adaptor($hs_dba);
#my $mm_gdb = $gdba->fetch_by_name_assembly($mouse_name,$mouse_assembly);
#$mm_gdb->db_adaptor($mm_dba);

my $dafa = $compara_dba->get_DnaAlignFeatureAdaptor;

subtest "Test fetch_by_region", sub {
    my $seq_region = 6;
    my $seq_region_start = 31500000;
    my $seq_region_end = 32000000;

    my $slice = $hs_dba->get_SliceAdaptor->fetch_by_region('toplevel',$seq_region,$seq_region_start,$seq_region_end);
    my $matches =
      $dafa->fetch_all_by_Slice($slice, $mouse_name, $mouse_assembly, "LASTZ_NET");

    my $num = scalar(@$matches);
    is($num > 10, 1, "At least 10 LASTZ_NET matches were expected against $mouse_name");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DnaAlignFeatureAdaptor::fetch_all_by_Slice", sub {
    my $seq_region = 6;
    my $seq_region_start = 31500000;
    my $seq_region_end = 32000000;

    my $slice = $hs_dba->get_SliceAdaptor->fetch_by_region('toplevel',$seq_region,$seq_region_start,$seq_region_end);
    my $matches =
	$dafa->fetch_all_by_Slice($slice, $mouse_name, $mouse_assembly, "LASTZ_NET");

    my $num = scalar(@$matches);
    is($num > 10, 1, "At least 10 LASTZ_NET matches were expected against mouse");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DnaAlignFeatureAdaptor::fetch_all_by_species_region", sub {
    my $seq_region = 6;
    my $seq_region_start = 31992884;
    my $seq_region_end = 31993082;
    #gab_id=6010001008434
    my $matches = $dafa->fetch_all_by_species_region(
                                                     $human_name,
                                                     $human_assembly,
                                                     $mouse_name,
                                                     $mouse_assembly,
                                                     $seq_region,
                                                     $seq_region_start,
                                                     $seq_region_end,
                                                     "LASTZ_NET",
                                                     0,
                                                     "chromosome"
                                                    );

    my $num = scalar(@$matches);
    is($num, 1);
    is($matches->[0]->{'seqname'}, $seq_region,
       "found an alignment outside of the searching region (unexpected name)!");
    is($matches->[0]->{'start'} < $seq_region_end, 1,
       "found an alignment outside of the searching region (unexpected start)!");
    is($matches->[0]->{'end'} > $seq_region_start, 1,
       "found an alignment outside of the searching region (unexpected end)!");
    is($matches->[0]->{'strand'}, 1, "Human should be in the +1 strand...");
    is($matches->[0]->{'species'}, "homo_sapiens",
       "found an alignment outside of the searching region (unexpected species)!");
    is($matches->[0]->{'score'} > 0, 1, "Alignment score is not >0");
    #like($matches->[0]->{'percent_id'}, 'm/\d+/', "\%id is not a number!");
    #is($matches->[0]->{'percent_id'} >= 0, 1, "Negative \%id!");
    #is($matches->[0]->{'percent_id'} <= 100, 1, "\%id > 100!");
    is($matches->[0]->{'hstart'} > 0, 1,
       "Funny coordinates (start !> 0)");
    is($matches->[0]->{'hend'} >= $matches->[0]->{'hstart'}, 1,
       "Funny coordinates (end < start)");
    is(($matches->[0]->{'hstrand'} == 1 or $matches->[0]->{'hstrand'} == -1), 1,
       "Funny strand");
    is($matches->[0]->{'hspecies'}, "mus_musculus");
    is($matches->[0]->{'align_type'}, "LASTZ_NET");
    is($matches->[0]->{'group_id'} > 1, 1, "Funny group_id");
    is($matches->[0]->{'level_id'}, 1);
    is($matches->[0]->{'strands_reversed'}, 0);
    like($matches->[0]->{'cigar_string'}, 'm/M/', "Funny cigar_string");
    
    done_testing();
};

subtest "Test fetch_by_region2", sub {
    my $seq_region = 6;
    my $seq_region_start = 31500000;
    my $seq_region_end = 32000000;

    my $hs_slice = $hs_dba->get_SliceAdaptor->fetch_by_region('toplevel',$seq_region,$seq_region_start,$seq_region_end);
    my $matches =
	$dafa->fetch_all_by_Slice($hs_slice, $mouse_name, $mouse_assembly, "LASTZ_NET");

    my $mm_slice = $mm_dba->get_SliceAdaptor->fetch_by_region('toplevel',
                                                           $matches->[0]->hseqname,
                                                           $matches->[0]->hstart,
                                                           $matches->[0]->hend);
    my $human_matches = 
      $dafa->fetch_all_by_Slice($mm_slice, $human_name, $human_assembly, "LASTZ_NET");
    
    my $num = scalar(@$human_matches);
    is($num >= 1, 1, "At least 1 LASTZ_NET match was expected against human");
    
    done_testing();
};

done_testing();

