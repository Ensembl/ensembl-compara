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

my $ref_species = "homo_sapiens";
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new('multi');
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");

my $hs_dba = $homo_sapiens->get_DBAdaptor('core');
my $compara_dba = $multi->get_DBAdaptor('compara');

my $human_assembly = $hs_dba->get_CoordSystemAdaptor->fetch_all->[0]->version;

my $gdba = $compara_dba->get_GenomeDBAdaptor;

my $hs_gdb = $gdba->fetch_by_name_assembly("homo_sapiens",$human_assembly);
$hs_gdb->db_adaptor($hs_dba);

my $ma = $compara_dba->get_SeqMemberAdaptor;
my $fa = $compara_dba->get_FamilyAdaptor;
my $mlssa = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

my $source = "ENSEMBLGENE";

is($source, 'ENSEMBLGENE');

done_testing();
