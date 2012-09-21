#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Bio::EnsEMBL::Utils::Exception qw (warning);
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Method;
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new("homo_sapiens");
my $mus_musculus = Bio::EnsEMBL::Test::MultiTestDB->new("mus_musculus");
my $rattus_norvegicus = Bio::EnsEMBL::Test::MultiTestDB->new("rattus_norvegicus");

my $compara_dba = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
  
my $method_link_species_set_adaptor;
my $method_link_species_sets;
my $method_link_species_set;
my $species;

# 
# Check premises
# 
ok(defined($multi) and defined($homo_sapiens) and defined($mus_musculus) and defined($rattus_norvegicus)
    and defined($compara_dba));

#
# Test new method
#

subtest "Test Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSet::new(ALL)", sub {

    my $method = new Bio::EnsEMBL::Compara::Method(
                                                   -dbID => 1,
                                                   -type => "BLASTZ_NET",
                                                   -class => "GenomicAlignBlock.pairwise_alignment");
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
    $gdb1->adaptor($genome_db_adaptor);

    my $gdb2 =  new Bio::EnsEMBL::Compara::GenomeDB(
                                                    undef,
                                                    "mus_musculus",       
                                                    "NCBIM36",
                                                    "10090",
                                                    "25",          
                                                    "2006-04-Ensembl");  
    $gdb2->adaptor($genome_db_adaptor);

    my $species_set = new Bio::EnsEMBL::Compara::SpeciesSet(-dbID => 30005,
                                                            -genome_dbs => [$gdb1, $gdb2]);
    
    my $mlss_name = "H.sap-M.mus blastz-net (on H.sap)";
    my $mlss_source = "ensembl";
    my $mlss_url;
    my $mlss_url_set = "http://hgdownload.cse.ucsc.edu/goldenPath/hg18/database/";
    my $mlss_classification = "Euarchontoglires:Eutheria:Mammalia:Euteleostomi:Vertebrata:Craniata:Chordata:Metazoa:Eukaryota";
    my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();

     $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
                                                                               -dbID => 1,
                                                                               -adaptor => $method_link_species_set_adaptor,
                                                                               -method => $method,
                                                                               -species_set_obj => $species_set,
                                                                               -name => $mlss_name,
                                                                               -source => $mlss_source);

    isa_ok($method_link_species_set, "Bio::EnsEMBL::Compara::MethodLinkSpeciesSet");
    is($method_link_species_set->dbID, 1);
    my $this_method = $method_link_species_set->method;
    is($this_method->dbID, 1);
    is($this_method->type, "BLASTZ_NET");
    is($this_method->class, "GenomicAlignBlock.pairwise_alignment");

    my $species = join(" - ", map {$_->name} sort {$a cmp $b} @{$method_link_species_set->species_set_obj->genome_dbs});
    is($species, "homo_sapiens - mus_musculus");
    
    is ($method_link_species_set->name, $mlss_name);
    is ($method_link_species_set->source, $mlss_source);
    is ($method_link_species_set->url, $mlss_url);

    $method_link_species_set->url($mlss_url_set);
    is ($method_link_species_set->url, $mlss_url_set);
    
    my $classification = join(":", map {$_} @{$method_link_species_set->get_common_classification});
    
    is ($classification, $mlss_classification);

    done_testing();
};

done_testing();

