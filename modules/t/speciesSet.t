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
use Bio::EnsEMBL::Utils::Exception qw (warning);
use Bio::EnsEMBL::Compara::SpeciesSet;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;


my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );

my $compara_dba = $multi->get_DBAdaptor( "compara" );

#
#Create genome_dbs
#
my $gdb1 =  new Bio::EnsEMBL::Compara::GenomeDB(
           undef,
           "homo_sapiens",       
           "NCBI36",
           "9606",
           "22",          
           "2006-08-Ensembl");  

my $gdb2 =  new Bio::EnsEMBL::Compara::GenomeDB(
           undef,
           "mus_musculus",       
           "NCBIM36",
           "10090",
           "25",          
           "2006-04-Ensembl");  

my $gdbs;
@$gdbs = ($gdb1, $gdb2);

# 
# 2. Check adaptor
# 
subtest "Check Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor", sub {
    my $species_set_adaptor = $compara_dba->get_SpeciesSetAdaptor();
    isa_ok($species_set_adaptor, "Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor");
    done_testing();
};

# 
# 3. Test new method
# 

subtest "Test Bio::EnsEMBL::Compara::SpeciesSet::new species_set", sub {
    my $species_set_adaptor = $compara_dba->get_SpeciesSetAdaptor();
    my $species_set = new Bio::EnsEMBL::Compara::SpeciesSet(
                                                            -dbID => 34795,
                                                            -genome_dbs => [$gdb1, $gdb2],
                                                            -adaptor => $species_set_adaptor );
    isa_ok($species_set, "Bio::EnsEMBL::Compara::SpeciesSet");
    is($species_set->dbID, 34795);

    my $species = $species_set->genome_dbs;
    
    is(@$species, 2);

    my %found;
    foreach my $spp (@$species) {
        $found{$spp->name} = 0;
        foreach my $gdb (@$gdbs) {
            if ($spp->name eq $gdb->name) {
                $found{$spp->name} = 1;
            }           
        }       
    }
    foreach my $spp (keys %found) {
        is($found{$spp}, 1);
    }

    done_testing();
};

done_testing();

