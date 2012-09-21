#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;


#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();

##
#####################################################################

my $genome_db;
my $all_genome_dbs;

my $num_eutheria = 35;
my ($num_of_genomes) = $compara_db_adaptor->dbc->db_handle->selectrow_array("SELECT count(*) FROM genome_db");
my ($eutheria_taxon_id) = $compara_db_adaptor->dbc->db_handle->selectrow_array('SELECT taxon_id FROM ncbi_taxa_name where name = "Eutheria"');

my ($genome_db_id, $taxon_id, $name, $assembly, $assembly_default, $genebuild,  $locator, $seq_region) = $compara_db_adaptor->dbc->db_handle->selectrow_array("SELECT genome_db_id, taxon_id, genome_db.name, assembly, assembly_default, genebuild, locator, dnafrag.name FROM genome_db JOIN dnafrag USING (genome_db_id) LIMIT 1");

#Need to add this explicitly 
Bio::EnsEMBL::Registry->add_alias("homo_sapiens", "human");

my $human_genome_db_id = $compara_db_adaptor->dbc->db_handle->selectrow_array("SELECT genome_db_id FROM genome_db WHERE name = 'homo_sapiens'");

my $core_dba = Bio::EnsEMBL::Test::MultiTestDB->new($name)->get_DBAdaptor("core");

#my $core_dba = $genome_db->db_adaptor;
my $slice = $core_dba->get_SliceAdaptor()->fetch_by_region('toplevel', $seq_region);

my $meta_container = Bio::EnsEMBL::Registry->get_adaptor($name, "core", "MetaContainer");


subtest "Test Bio::EnsEMBL::Compara::GenomeDB::fetch_by_dbID", sub {

    my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);
    isa_ok($genome_db, "Bio::EnsEMBL::Compara::GenomeDB", "check object");

    $genome_db = $genome_db_adaptor->fetch_by_dbID(-$genome_db_id);
    is($genome_db, undef, "Fetching Bio::EnsEMBL::Compara::GenomeDB by unknown dbID");


    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::fetch_all", sub {
    $all_genome_dbs = $genome_db_adaptor->fetch_all();
    is(scalar(@$all_genome_dbs), $num_of_genomes, "Checking the total number of genomes");
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::fetch_by_dbID", sub {
    my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);

    is($genome_db->name, $name, "Checking genome_db name");
    is($genome_db->assembly_default, $assembly_default, "Checking genome_db assembly_default");
    is($genome_db->assembly, $assembly, "Checking genome_db assembly");
    is($genome_db->genebuild, $genebuild, "Checking genome_db genebuild");
    is($genome_db->taxon_id, $taxon_id, "Checking genome_db taxon_id");
    is($genome_db->locator, $locator, "Checking genome_db locator");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::fetch_by_name_assembly" , sub {

    my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($name);
    is($genome_db->dbID, $genome_db_id, "Fetching by name and default assembly");
    
    $genome_db = $genome_db_adaptor->fetch_by_name_assembly($name, $assembly);
    is($genome_db->dbID, $genome_db_id, "Fetching by name and assembly");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::fetch_by_taxon_id", sub {

    my $genome_db = $genome_db_adaptor->fetch_by_taxon_id($taxon_id);
    is($genome_db->dbID, $genome_db_id, "Fetching by taxon_id");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::fetch_by_registry_name", sub {
    
    my $genome_db = $genome_db_adaptor->fetch_by_registry_name("human");
    is($genome_db->dbID, $human_genome_db_id, "Fetching by registry name");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::fetch_by_Slice", sub {

    my $genome_db = $genome_db_adaptor->fetch_by_Slice($slice);
    is($genome_db->dbID, $genome_db_id, "Fetching by slice");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::fetch_all_by_ancestral_taxon_id", sub {

    my $eutherian_genome_dbs = $genome_db_adaptor->fetch_all_by_ancestral_taxon_id($eutheria_taxon_id);
    is(scalar(@$eutherian_genome_dbs), $num_eutheria, "Checking the total number of eutherian mammals");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::fetch_by_core_DBAdaptor", sub {

    my $genome_db = $genome_db_adaptor->fetch_by_core_DBAdaptor($core_dba);
    is($genome_db->dbID, $genome_db_id, "Fetching by core adaptor");
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::get_species_name_from_core_MetaContainer", sub {
    my $species_name = $genome_db_adaptor->get_species_name_from_core_MetaContainer($meta_container);
    is ($species_name, $name, "Get species name from core meta container");
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::synchronise", sub {

    my $syn_genome_db = Bio::EnsEMBL::Compara::GenomeDB->new(-taxon_id => $taxon_id);
    throws_ok { $genome_db_adaptor->synchronise($syn_genome_db) } qr/GenomeDB object with a non-zero taxon_id must have a name, assembly and genebuild/, 'ysnchronise throw: No name and assembly and genebuild causes an error';
    
    $syn_genome_db = Bio::EnsEMBL::Compara::GenomeDB->new(-name => $name,
                                                          -taxon_id => $taxon_id);
    throws_ok { $genome_db_adaptor->synchronise($syn_genome_db) } qr/GenomeDB object with a non-zero taxon_id must have a name, assembly and genebuild/, 'synchronise throw:No assembly and genebuild causes an error';
    
    $syn_genome_db = Bio::EnsEMBL::Compara::GenomeDB->new(-name     => $name,
                                                          -assembly => $assembly,
                                                          -taxon_id => $taxon_id);
    throws_ok { $genome_db_adaptor->synchronise($syn_genome_db) } qr/GenomeDB object with a non-zero taxon_id must have a name, assembly and genebuild/, 'synchronise throw: No genebuild causes an error';


    my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);
    my $syn_genome_db_id = $genome_db_adaptor->synchronise($genome_db);
    is ($syn_genome_db_id, $genome_db->dbID, 'synchronise with valid genome_db');
    
    $syn_genome_db = Bio::EnsEMBL::Compara::GenomeDB->new();
    $syn_genome_db_id = $genome_db_adaptor->synchronise($syn_genome_db);
    is ($syn_genome_db_id, undef, 'empty genome_db');


    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::cache_all and Bio::EnsEMBL::Compara::GenomeDB::store", sub {

    my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);

    $multi->hide('compara', 'genome_db');

    ## List of genomes are cached in the Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
    $genome_db_adaptor->cache_all(1); # force reload
    my $all_genome_dbs = $genome_db_adaptor->fetch_all();
    is(scalar(@$all_genome_dbs), 0, "Checking hide method");

    $genome_db_adaptor->store($genome_db);
    ## List of genomes are cached in a couple of globals in the Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
    $genome_db_adaptor->cache_all; # reset globals
    $all_genome_dbs = $genome_db_adaptor->fetch_all();
    is(scalar(@$all_genome_dbs), 1, "Checking store method");
    
    $multi->restore('compara', 'genome_db');
    ## List of genomes are cached in a couple of globals in the Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
    $genome_db_adaptor->cache_all(1); # reset globals
    $all_genome_dbs = $genome_db_adaptor->fetch_all();
    is(scalar(@$all_genome_dbs), $num_of_genomes, "Checking restore method");

    $genome_db_adaptor->sync_with_registry();

    done_testing();
};

done_testing();
