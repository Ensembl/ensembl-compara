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
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::SpeciesSet;

my $species = [
        "homo_sapiens",
    ];

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $species_set_adaptor = $compara_db_adaptor->get_SpeciesSetAdaptor();
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();

my ($num_species_sets) = $compara_db_adaptor->dbc->db_handle->selectrow_array("SELECT count(distinct species_set_id) FROM species_set");


#
#Create genome_dbs
#
my $gdb1 =  new Bio::EnsEMBL::Compara::GenomeDB(
           -db_adaptor => undef,
           -name => "homo_sapiensa",       
           -assembly => "NCBI361",
           -taxon_id => "9606",
           -genebuild => "2006-08-Ensembl");

my $gdb2 =  new Bio::EnsEMBL::Compara::GenomeDB(
           -db_adaptor => undef,
           -name => "mus_musculusa",       
           -assembly => "NCBIM361",
           -taxon_id => "10090",
           -genebuild => "2006-04-Ensembl");

my $gdbs;
@$gdbs = ($gdb1, $gdb2);


#Test adding single species set
subtest "Test Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor::store1", sub {
    #store new species_set
    my $species_set = Bio::EnsEMBL::Compara::SpeciesSet->new(
                                                  -genome_dbs => [ $genome_db_adaptor->fetch_by_name_assembly("felis_catus"),
                                                                 $genome_db_adaptor->fetch_by_name_assembly("mus_musculus")],                                                               );

    $multi->hide('compara', 'species_set_header', 'species_set', 'genome_db', 'species_set_tag');
    $species_set_adaptor->store($species_set);
    is(scalar(@{$species_set_adaptor->fetch_all}), 1);

    $multi->restore('compara', 'species_set_header', 'species_set', 'genome_db', 'species_set_tag');
    done_testing();  
};

#Test adding 2 species sets, where the second one already exists
subtest "Test Bio::EnsEMBL::Compara::DBSQL::SpeciesSetAdaptor::store2", sub {
                                                                
   #Make sure the cache is empty
    $species_set_adaptor->{_id_cache}->clear_cache;

    $multi->save('compara', 'species_set_header', 'species_set', 'genome_db', 'species_set_tag');

    #new object with no genome_dbs
    my $new_species_set = Bio::EnsEMBL::Compara::SpeciesSet->new();    

    $species_set_adaptor->store($new_species_set);
    my $all_species_sets = $species_set_adaptor->fetch_all();
    is(scalar(@$all_species_sets), ($num_species_sets+1), "Checking store method");

    #existing species set
    my $species_set = Bio::EnsEMBL::Compara::SpeciesSet->new(
                          -genome_dbs => [ $genome_db_adaptor->fetch_by_name_assembly("felis_catus"),
                                            $genome_db_adaptor->fetch_by_name_assembly("mus_musculus")],
                                                              );

    $species_set_adaptor->store($species_set);
    $all_species_sets = $species_set_adaptor->fetch_all();
    is(scalar(@$all_species_sets), ($num_species_sets+1), "Checking store method");

    $multi->restore('compara', 'species_set_header', 'species_set', 'genome_db', 'species_set_tag');
    done_testing();  
};

done_testing();
