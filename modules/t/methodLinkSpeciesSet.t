#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );

my $compara_dba = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
  
my $method_link_species_set_adaptor;
my $method_link_species_set;

# 
# Check premises
# 
ok(defined($multi) and defined($compara_dba));

# Create genome_dbs
my $gdb1 =  new Bio::EnsEMBL::Compara::GenomeDB(
    -name      => 'homo_sapiens',
    -assembly  => 'NCBI36',
    -taxon_id  => 9606,
    -dbID      => 22,
    -genebuild => '2006-08-Ensembl'
);
$gdb1->adaptor($genome_db_adaptor);
my $gdb2 =  new Bio::EnsEMBL::Compara::GenomeDB(
    -name      => 'mus_musculus',
    -assembly  => 'NCBIM36',
    -taxon_id  => 10090,
    -dbID      => 25,
    -genebuild => '2006-04-Ensembl'
);
$gdb2->adaptor($genome_db_adaptor);

#
# Test new method
#

subtest "Test Bio::EnsEMBL::Compara::MethodLinkSpeciesSet::new(ALL)", sub {

    my $method = new Bio::EnsEMBL::Compara::Method(
                                                   -dbID => 1,
                                                   -type => "BLASTZ_NET",
                                                   -class => "GenomicAlignBlock.pairwise_alignment");

    my $species_set = new Bio::EnsEMBL::Compara::SpeciesSet(-dbID => 30005,
                                                            -genome_dbs => [$gdb1, $gdb2]);

    my $mlss_name = "H.sap-M.mus blastz-net (on H.sap)";
    my $mlss_source = "ensembl";
    my $mlss_url;
    my $mlss_url_set = "https://hgdownload.cse.ucsc.edu/goldenPath/hg18/database/";
    my $mlss_classification = "Euarchontoglires:Eutheria:Mammalia:Euteleostomi:Vertebrata:Craniata:Chordata:Metazoa:Eukaryota";
    my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();

     $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
                                                                               -dbID => 1,
                                                                               -adaptor => $method_link_species_set_adaptor,
                                                                               -method => $method,
                                                                               -species_set => $species_set,
                                                                               -name => $mlss_name,
                                                                               -source => $mlss_source);

    isa_ok($method_link_species_set, "Bio::EnsEMBL::Compara::MethodLinkSpeciesSet");
    is($method_link_species_set->dbID, 1);
    my $this_method = $method_link_species_set->method;
    is($this_method->dbID, 1);
    is($this_method->type, "BLASTZ_NET");
    is($this_method->class, "GenomicAlignBlock.pairwise_alignment");

    my $species = join(" - ", sort {$a cmp $b} map {$_->name} @{$method_link_species_set->species_set->genome_dbs});
    is($species, "homo_sapiens - mus_musculus");
    
    is ($method_link_species_set->name, $mlss_name);
    is ($method_link_species_set->source, $mlss_source);
    is ($method_link_species_set->url, $mlss_url);

    $method_link_species_set->url($mlss_url_set);
    is ($method_link_species_set->url, $mlss_url_set);
    
    my $classification = join(":", map {$_} @{$method_link_species_set->species_set->get_common_classification});
    
    is ($classification, $mlss_classification);
};


subtest "Test Bio::EnsEMBL::Compara::MethodLinkSpeciesSet::find_pairwise_reference", sub {
    $method_link_species_set->add_tag('reference_species', 'homo_sapiens');
    my $genome_dbs = [$gdb1, $gdb2];
    my @returned_gdbs = $method_link_species_set->find_pairwise_reference();
    is_deeply(\@returned_gdbs, $genome_dbs, 'Correct genome_dbs and order returned');
};

done_testing();

