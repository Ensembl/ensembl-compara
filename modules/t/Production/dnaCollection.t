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

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::Production::DnaCollection;

# switch on the debug prints
our $verbose = 1;

#
# Set up some objects 
#

my $description = "homo_sapiens raw";
my $dbid = 2;
my $dump_loc = "/lustre/scratch109/ensembl/kb3/scratch/t/Production";
my $masking_options_default = "{default_soft_masking => 1}";
my $masking_options_human = '{"repeat_class_RNA" => 0,"repeat_class_SINE/Alu" => 0,"repeat_class_Satellite" => 0,"repeat_class_Satellite/acro" => 0}';

#
# Compiles
#
ok(1);

#
# Create empty genomic_align_block object
#

my $dna_collection = new Bio::EnsEMBL::Compara::Production::DnaCollection();
isa_ok($dna_collection, "Bio::EnsEMBL::Compara::Production::DnaCollection");

#
# Create non-empty dna_collection object
#
subtest "Test Bio::EnsEMBL::Compara::Production::DnaCollection new method", sub {
    my $dna_collection = new Bio::EnsEMBL::Compara::Production::DnaCollection(-description => $description,
                                                                              -dbid => $dbid,
                                                                              -dump_loc => $dump_loc,
                                                                              -masking_options => $masking_options_default);
    isa_ok($dna_collection, "Bio::EnsEMBL::Compara::Production::DnaCollection");

    is($dna_collection->description, $description, "description");
    is($dna_collection->dbID, $dbid, "dbID");
    is($dna_collection->dump_loc, $dump_loc, "dump_loc");
    is($dna_collection->masking_options, $masking_options_default, "masking_options");

    #Still to do...
    #get_all_dnafrag_chunk_sets
    #count

    done_testing();
};

done_testing();
