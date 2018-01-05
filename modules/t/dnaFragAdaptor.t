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
use Bio::EnsEMBL::Compara::GenomicAlign;

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();
my $genomic_align_adaptor = $compara_db_adaptor->get_GenomicAlignAdaptor();

##
#####################################################################

my $dnafrag_adaptor = $compara_db_adaptor->get_DnaFragAdaptor();
isa_ok($dnafrag_adaptor, 'Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor', "Getting the adaptor");

    
#####################################################################
## Values matching entries in the test DB

my $ref_species = "homo_sapiens";
my $hs_core_db = Bio::EnsEMBL::Test::MultiTestDB->new($ref_species);

my $sth = $multi->get_DBAdaptor( "compara" )->dbc->prepare("SELECT
      DISTINCT(gdb.name)
    FROM dnafrag df join genome_db gdb using (genome_db_id)");

$sth->execute();
my @species_names;
while (my $row = $sth->fetchrow_array) {
    push @species_names, $row;
}
$sth->finish();


##
#####################################################################
$sth = $multi->get_DBAdaptor( "compara" )->dbc->prepare("SELECT
      dnafrag_id, length, df.name, df.genome_db_id, coord_system_name
    FROM dnafrag df left join genome_db gdb USING (genome_db_id)
    WHERE gdb.name = \"$ref_species\" LIMIT 1");
$sth->execute();
my ($dnafrag_id, $dnafrag_length, $dnafrag_name, $genome_db_id, $coord_system_name) =
  $sth->fetchrow_array();
$sth->finish();

subtest "Test Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor fetch_by_dbID($dnafrag_id) method", sub {

    my $dnafrag;
    my $dnafrags;

    $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);
    isa_ok($dnafrag, 'Bio::EnsEMBL::Compara::DnaFrag', "Fetching by dbID");
    is($dnafrag->dbID, $dnafrag_id, "Fetching by dbID. Checking dbID");
    is($dnafrag->length, $dnafrag_length, "Fetching by dbID. Checking length");
    is($dnafrag->name, $dnafrag_name, "Fetching by dbID. Checking name");
    is($dnafrag->genome_db_id, $genome_db_id, "Fetching by dbID. Checking genome_db_id");
    is($dnafrag->coord_system_name, $coord_system_name, "Fetching by dbID. Checking coord_system_name");
    
    $dnafrag = eval { $dnafrag_adaptor->fetch_by_dbID(-$dnafrag_id) };
    is($dnafrag, undef, "Fetching by dbID with wrong dbID");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor::fetch_by_GenomeDB_and_name method", sub {

    my $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($genome_db_id, $dnafrag_name);
    isa_ok($dnafrag, 'Bio::EnsEMBL::Compara::DnaFrag', "Fetching by GenomeDB and name");
    is($dnafrag->dbID, $dnafrag_id, "Fetching by GenomeDB and name. Checking dbID");
    is($dnafrag->length, $dnafrag_length, "Fetching by GenomeDB and name. Checking length");
    is($dnafrag->name, $dnafrag_name, "Fetching by GenomeDB and name. Checking name");
    is($dnafrag->genome_db_id, $genome_db_id, "Fetching by GenomeDB and name. Checking genome_db_id");
    is($dnafrag->coord_system_name, $coord_system_name, "Fetching by GenomeDB and name. Checking coord_system_name");

    $dnafrag = eval { $dnafrag_adaptor->fetch_by_GenomeDB_and_name(-$genome_db_id, $dnafrag_name) };
    is($dnafrag, undef, "Fetching by GenomeDB and name with a wrong genome_db_id");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor::fetch_all_by_GenomeDB_region method", sub {

    my $dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region(
                                                                  $genome_db_adaptor->fetch_by_dbID($genome_db_id),
                                                                  $coord_system_name,
                                                                  $dnafrag_name
                                                                 );
    is(@$dnafrags, 1);
    isa_ok($dnafrags->[0], 'Bio::EnsEMBL::Compara::DnaFrag', "Fetching all by GenomeDB and region");
    is($dnafrags->[0]->dbID, $dnafrag_id, "Fetching all by GenomeDB and region. Checking dbID");
    is($dnafrags->[0]->length, $dnafrag_length, "Fetching all by GenomeDB and region. Checking length");
    is($dnafrags->[0]->name, $dnafrag_name, "Fetching all by GenomeDB and region. Checking name");
    is($dnafrags->[0]->genome_db_id, $genome_db_id, "Fetching all by GenomeDB and region. Checking genome_db_id");
    is($dnafrags->[0]->coord_system_name, $coord_system_name, "Fetching all by GenomeDB and region. Checking coord_system_name");

};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor::fetch_all_by_GenomeDB_region method (all genomes) and fetch_all method", sub {

    my $num_of_dnafrags = 0;

    foreach my $this_species_name (@species_names) {
        my $dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region(
                                                                   $genome_db_adaptor->fetch_by_name_assembly($this_species_name)
                                                                  );
        my $fail = "";
        if (!(@$dnafrags >= 1)) {
            $fail .= "At least 1 DnaFrag was expected for species $this_species_name";
        }
        $num_of_dnafrags += @$dnafrags;
        foreach my $dnafrag (@$dnafrags) {
            if (!($dnafrag->dbID>0)) {
                $fail .= "Found unexpected dnafrag_id (".$dnafrag->dbID.") for species $this_species_name";
                next;
            }
            if (!($dnafrag->length>0)) {
                $fail .= "Found unexpected dnafrag_length (".$dnafrag->length.") for DnaFrag(".$dnafrag->dbID.")";
            }
        }
        is($fail, "", "Fetching all by GenomeDB and region");
    };

    #Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor::fetch_all
    my $dnafrags = $dnafrag_adaptor->fetch_all();
    is(@$dnafrags, $num_of_dnafrags, "Fetching all");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor::fetch_by_Slice", sub {
    
    my $sth = $compara_db_adaptor->dbc->prepare("SELECT
      genomic_align_id, genomic_align_block_id, method_link_species_set_id, dnafrag_id,
      dnafrag_start, dnafrag_end, dnafrag_strand, cigar_line, visible, node_id
    FROM genomic_align JOIN dnafrag USING (dnafrag_id) JOIN genome_db gdb USING (genome_db_id) WHERE gdb.name = '$ref_species' AND dnafrag_id = ? LIMIT 1");
    $sth->execute($dnafrag_id);
    my ($dbID, $genomic_align_block_id, $method_link_species_set_id, $dnafrag_id,
        $dnafrag_start, $dnafrag_end, $dnafrag_strand, $cigar_line, $visible, $node_id) =
          $sth->fetchrow_array();
    $sth->finish();

    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(-adaptor => $genomic_align_adaptor,
                                                                -dbID => $dbID);
    my $slice = $genomic_align->get_Slice();
    my $dnafrag = $dnafrag_adaptor->fetch_by_Slice($slice);

    isa_ok($dnafrag, 'Bio::EnsEMBL::Compara::DnaFrag', "Fetching all by GenomeDB and region");
    is($dnafrag->dbID, $dnafrag_id, "Fetching all by GenomeDB and region. Checking dbID");
    is($dnafrag->length, $dnafrag_length, "Fetching all by GenomeDB and region. Checking length");
    is($dnafrag->name, $dnafrag_name, "Fetching all by GenomeDB and region. Checking name");
    is($dnafrag->genome_db_id, $genome_db_id, "Fetching all by GenomeDB and region. Checking genome_db_id");
    is($dnafrag->coord_system_name, $coord_system_name, "Fetching all by GenomeDB and region. Checking coord_system_name");

    done_testing();
};


subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor::_synchronise", sub {

    throws_ok { $dnafrag_adaptor->_synchronise() } qr/MSG: The given reference for attribute argument to _synchronise was undef. Expected 'Bio::EnsEMBL::Compara::DnaFrag'/, 'no argument passed';
    throws_ok { $dnafrag_adaptor->_synchronise($dnafrag_id) } qr/MSG: Asking for the type of the attribute argument to _synchronise produced no type; check it is a reference. Expected 'Bio::EnsEMBL::Compara::DnaFrag'/, 'invalid dnafrag object';

    my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);
    $dnafrag->adaptor(undef);
    $dnafrag->dbID(undef);
    $dnafrag_adaptor->_synchronise($dnafrag);
    is($dnafrag->dbID, $dnafrag_id, "already stored");

    my $new_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
                                                         -length => 12345,
                                                         -name => "F",
                                                         -genome_db  => $dnafrag->genome_db,
                                                         -genome_db_id  => $dnafrag->genome_db_id,
                                                         -coord_system_name => "chromosome");
    
    is($dnafrag_adaptor->_synchronise($new_dnafrag), undef, 'not stored');

    done_testing();
};



subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor::store", sub {

    my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);
    $multi->hide("compara", "dnafrag");
    
    my $dnafrags = $dnafrag_adaptor->fetch_all();
    is(@$dnafrags, 0, "Fetching all after hiding table");

    #
    $dnafrag->genome_db;
    $dnafrag->{adaptor} = undef;
    $dnafrag_adaptor->store($dnafrag);
    $dnafrags = $dnafrag_adaptor->fetch_all();
    is(@$dnafrags, 1, "Fetching all after hiding table");
    $dnafrag->{adaptor} = undef;
    $dnafrag_adaptor->store_if_needed($dnafrag);
    $dnafrags = $dnafrag_adaptor->fetch_all();
    is(@$dnafrags, 1, "Fetching all after hiding table");

    my $new_dnafrag = $dnafrags->[0];
    is($new_dnafrag->length, $dnafrag_length, "store length");

    #alter length
    $new_dnafrag->length(12345);
    $dnafrag_adaptor->update($new_dnafrag);

    $dnafrags = $dnafrag_adaptor->fetch_all();
    is($dnafrags->[0]->length, 12345, "updated length");

    #New dnafrag
    $new_dnafrag->genome_db;    # Load the GenomeDB as long as we have an adaptor
    $new_dnafrag->{adaptor} = undef;
    $new_dnafrag->name("Z");
    $dnafrag_adaptor->store($new_dnafrag);
    $dnafrags = $dnafrag_adaptor->fetch_all();
    is(@$dnafrags, 2, "Fetching all after update to store new dnafrag");

    $multi->restore("compara", "dnafrag");

    done_testing();
};

done_testing();
