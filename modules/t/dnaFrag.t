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
 
use Test::Harness;
use Test::More;

use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Utils::Exception qw(verbose);
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::GenomeDB;

my $species = [
        "homo_sapiens",
        "felis_catus",
        "rattus_norvegicus",
    ];

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_dba = $multi->get_DBAdaptor( "compara" );
my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor();
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();

my $species_db;
## Connect to core DB specified in the MultiTestDB.conf file
foreach my $this_species (@$species) {
  $species_db->{$this_species} = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
  die if (!$species_db->{$this_species});
}

##
#####################################################################

my $sth = $compara_dba->dbc->prepare("SELECT dnafrag_id, length, name, genome_db_id, coord_system_name, is_reference FROM dnafrag LIMIT 1");
$sth->execute();
my ($dbID, $length, $name, $genome_db_id, $coord_system_name, $is_reference) = $sth->fetchrow_array();
$sth->finish();

my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);

subtest "Test Bio::EnsEMBL::Compara::DnaFrag::new(void)", sub {

    my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag();
    isa_ok($dnafrag, "Bio::EnsEMBL::Compara::DnaFrag");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DnaFrag::new(all)", sub {

    my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
                                                  -adaptor => $dnafrag_adaptor,
                                                  -genome_db_id => $genome_db_id,
                                                  -coord_system_name => $coord_system_name,
                                                  -name => $name
                                                 );
    isa_ok($dnafrag, "Bio::EnsEMBL::Compara::DnaFrag");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DnaFrag::getter/setters", sub {
    my $dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
                                                     -adaptor => $dnafrag_adaptor,
                                                     -genome_db_id => $genome_db_id,
                                                     -coord_system_name => $coord_system_name,
                                                     -name => $name
                                                    );

    ok(test_getter_setter($dnafrag, "dbID", $dbID));
    ok(test_getter_setter($dnafrag, "adaptor", $dnafrag_adaptor));
    ok(test_getter_setter($dnafrag, "length", $length));
    ok(test_getter_setter($dnafrag, "name", $name));
    ok(test_getter_setter($dnafrag, "genome_db", $genome_db));
    ok(test_getter_setter($dnafrag, "genome_db_id", $genome_db_id));
    ok(test_getter_setter($dnafrag, "coord_system_name", $coord_system_name));
    ok(test_getter_setter($dnafrag, "is_reference", $is_reference));

    isa_ok($dnafrag->slice, "Bio::EnsEMBL::Slice");

    my $display_id = $genome_db->taxon_id . "." . $genome_db->dbID. ":". $coord_system_name.":".$name;
    ok(test_getter_setter($dnafrag, "display_id", $display_id));

    done_testing();
};


done_testing();
