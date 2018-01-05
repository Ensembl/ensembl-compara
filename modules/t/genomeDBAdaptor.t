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

my $species = [
        "homo_sapiens",
    ];

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );

my $species_db;
my $species_db_adaptor;
## Connect to core DB specified in the MultiTestDB.conf file
foreach my $this_species (@$species) {
  $species_db->{$this_species} = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
  die if (!$species_db->{$this_species});
  $species_db_adaptor->{$this_species} = $species_db->{$this_species}->get_DBAdaptor('core');
}

my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();

##
#####################################################################

my $genome_db;
my $all_genome_dbs;

my $num_eutheria = 35;
my ($num_of_genomes) = $compara_db_adaptor->dbc->db_handle->selectrow_array("SELECT count(*) FROM genome_db");
my ($eutheria_taxon_id) = $compara_db_adaptor->dbc->db_handle->selectrow_array('SELECT taxon_id FROM ncbi_taxa_name where name = "Eutheria"');

my ($genome_db_id, $taxon_id, $name, $assembly, $first_release, $last_release, $genebuild,  $locator, $seq_region) = $compara_db_adaptor->dbc->db_handle->selectrow_array("SELECT genome_db_id, taxon_id, genome_db.name, assembly, first_release, last_release, genebuild, locator, dnafrag.name FROM genome_db JOIN dnafrag USING (genome_db_id) WHERE genome_db.name = 'homo_sapiens' LIMIT 1");

#Need to add this explicitly 
Bio::EnsEMBL::Registry->add_alias("homo_sapiens", "human");

my $human_genome_db_id = $compara_db_adaptor->dbc->db_handle->selectrow_array("SELECT genome_db_id FROM genome_db WHERE name = 'homo_sapiens'");

my $core_dba = $species_db_adaptor->{$name};

#my $core_dba = $genome_db->db_adaptor;
my $slice = $core_dba->get_SliceAdaptor()->fetch_by_region('toplevel', $seq_region);

my $meta_container = Bio::EnsEMBL::Registry->get_adaptor($name, "core", "MetaContainer");


subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor::fetch_by_dbID", sub {

    my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);
    isa_ok($genome_db, "Bio::EnsEMBL::Compara::GenomeDB", "check object");

    $genome_db = $genome_db_adaptor->fetch_by_dbID(-$genome_db_id);
    is($genome_db, undef, "Fetching Bio::EnsEMBL::Compara::GenomeDB by unknown dbID");


    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor::fetch_all", sub {
    $all_genome_dbs = $genome_db_adaptor->fetch_all();
    is(scalar(@$all_genome_dbs), $num_of_genomes, "Checking the total number of genomes");
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::fetch_by_dbID", sub {
    my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);

    is($genome_db->name, $name, "Checking genome_db name");
    is($genome_db->first_release, $first_release, "Checking genome_db first_release");
    is($genome_db->last_release, $last_release, "Checking genome_db last_release");
    is($genome_db->assembly, $assembly, "Checking genome_db assembly");
    is($genome_db->genebuild, $genebuild, "Checking genome_db genebuild");
    is($genome_db->taxon_id, $taxon_id, "Checking genome_db taxon_id");
    is($genome_db->locator, undef, "Checking genome_db locator");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::new_from_DBAdaptor", sub {
    my $hs_dba = $species_db_adaptor->{'homo_sapiens'};
    my $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new_from_DBAdaptor($hs_dba);

    is($genome_db->name, $name, "Checking genome_db name");
    is($genome_db->assembly, $assembly, "Checking genome_db assembly");
    is($genome_db->genebuild, $genebuild, "Checking genome_db genebuild");
    is($genome_db->taxon_id, $taxon_id, "Checking genome_db taxon_id");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::fetch_by_name_assembly" , sub {

    my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($name);
    is($genome_db->dbID, $genome_db_id, "Fetching by name and default assembly");
    
    $genome_db = $genome_db_adaptor->fetch_by_name_assembly($name, $assembly);
    is($genome_db->dbID, $genome_db_id, "Fetching by name and assembly");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::GenomeDB::fetch_all_by_taxon_id", sub {

    my $genome_dbs = $genome_db_adaptor->fetch_all_by_taxon_id($taxon_id);
    is(scalar(@$genome_dbs), 1, 'Got 1 GenomeDB');
    is($genome_dbs->[0]->dbID, $genome_db_id, "Fetching by taxon_id");

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

#Store new genome_db
subtest "Test Bio::EnsEMBL::Compara::GenomeDB::store", sub {
    my $hs_dba = $species_db_adaptor->{'homo_sapiens'};
    my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);

    $multi->hide('compara', 'genome_db');

    #Make sure the cache is empty
    $genome_db_adaptor->{_id_cache}->clear_cache;

    #disconnect the GenomeDB from the adaptor
    $genome_db->adaptor(undef);

    #store new genome_db
    $genome_db_adaptor->store($genome_db);

    ## List of genomes are cached in a couple of globals in the Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
    $all_genome_dbs = $genome_db_adaptor->fetch_all();
    is(scalar(@$all_genome_dbs), 1, "Checking store method");

    $multi->restore('compara', 'genome_db');

    done_testing();
};

done_testing();
