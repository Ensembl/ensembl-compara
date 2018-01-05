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

use Bio::EnsEMBL::Utils::Exception qw (warning verbose);
use Bio::EnsEMBL::Test::MultiTestDB;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Compara::ConstrainedElement;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use File::Find;
use FindBin qw/$Bin/;
use File::Spec::Functions qw/updir catfile/;

my $ref_species = "homo_sapiens";
my $species = [
        "homo_sapiens",
    ];

#####################################################################
## Connect to the test database using the MultiTestDB.conf file
my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_dba = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
  
my $species_db;
my $species_db_adaptor;
## Connect to core DB specified in the MultiTestDB.conf file
foreach my $this_species (@$species) {
    $species_db->{$this_species} = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
  die if (!$species_db->{$this_species});
  $species_db_adaptor->{$this_species} = $species_db->{$this_species}->get_DBAdaptor('core');
}

##
#####################################################################

my $constrained_element_adaptor = $compara_dba->get_ConstrainedElementAdaptor();
my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor();

#####################################################################
##  DATA USED TO TEST API
##

my ($constrained_element_id, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand, $method_link_species_set_id, $p_value,
     $score) = 
       $compara_dba->dbc->db_handle->selectrow_array("SELECT * FROM constrained_element LIMIT 1");

my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);

#my ($num_of_constrained_elements) = $compara_dba->dbc->db_handle->selectrow_array("SELECT count(*) FROM constrained_element WHERE method_link_species_set_id=$method_link_species_set_id");

my ($num_of_constrained_elements) = count_rows($compara_dba, "constrained_element", "WHERE method_link_species_set_id=?", [$method_link_species_set_id]);

#my $all_constrained_element_ids = $compara_db_adaptor->dbc->db_handle->selectcol_arrayref("
my $all_ids = $compara_dba->dbc->db_handle->selectcol_arrayref("
    SELECT constrained_element_id
    FROM constrained_element
    WHERE method_link_species_set_id = $method_link_species_set_id
      and dnafrag_id = $dnafrag_id");

my $all_constrained_element_ids;
foreach my $id (@$all_ids) {
    $all_constrained_element_ids->{$id} = 1;
}

#Slice
my $slice_adaptor = $species_db_adaptor->{$ref_species}->get_SliceAdaptor();

my $slice_coord_system_name = $dnafrag->coord_system_name;
my $slice_seq_region_name = $dnafrag->name;
my $slice_start = $dnafrag_start;
my $slice_end = $dnafrag_end;
my $slice = $slice_adaptor->fetch_by_region($slice_coord_system_name,$slice_seq_region_name,$slice_start,$slice_end);

subtest "Test Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor->fetch_by_dbID method", sub {
  my $ce = $constrained_element_adaptor->fetch_by_dbID($constrained_element_id);
  isa_ok($ce, "Bio::EnsEMBL::Compara::ConstrainedElement", "check object");
  is($ce->dbID, $constrained_element_id);
  is($ce->adaptor, $constrained_element_adaptor);
  is($ce->method_link_species_set_id, $method_link_species_set_id);
  is($ce->score, $score);
  is($ce->p_value, $p_value);
#  is($ce->seq_region_start, $dnafrag_start);
  
  done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor->fetch_all_by_dbID_list method", sub {

    #try having a list of ce_ids...
    my $all_ces = $constrained_element_adaptor->fetch_all_by_dbID_list([$constrained_element_id]);

    foreach my $ce (@$all_ces) {
        isa_ok($ce, "Bio::EnsEMBL::Compara::ConstrainedElement", "check object");
        is($ce->dbID, $constrained_element_id);
        is($ce->adaptor, $constrained_element_adaptor);
        is($ce->method_link_species_set_id, $method_link_species_set_id);
        is($ce->score, $score);
        is($ce->p_value, $p_value);
        #  is($ce->seq_region_start, $dnafrag_start);
    }
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag method", sub {
    my $slice_start = 31500000;
    my $slice_end = 32000000;

  my $all_ces = $constrained_element_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
          $method_link_species_set,
          $dnafrag,
          $slice_start,
          $slice_end
  );

  is(scalar(@$all_ces), $num_of_constrained_elements, "Checking number of constrained_elements");

  foreach my $ce (@$all_ces) {
      ok($all_constrained_element_ids->{$ce->dbID}, "checking ids");
  }

  done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor fetch_by_MethodLinkSpeciesSet_Slice() method" , sub {
    my $slice_start = 31500000;
    my $slice_end = 32000000;
    my $slice = $slice_adaptor->fetch_by_region(
                                                $slice_coord_system_name,
                                                $slice_seq_region_name,
                                                $slice_start,
                                                $slice_end
                                               );

    my $constrained_elements = $constrained_element_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_set, $slice);
    
    is(scalar(@$constrained_elements), $num_of_constrained_elements, "Checking number of constrained_elements");
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor->count_by_mlss_id method", sub {
    my $count = $constrained_element_adaptor->count_by_mlss_id($method_link_species_set_id);
    is ($count, $num_of_constrained_elements);

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor->store method", sub {

    load_pipeline_tables($compara_dba, "constrained_element_production");
    my $orig_ce = $constrained_element_adaptor->fetch_by_dbID($constrained_element_id);

    my $constrained_element_block;
    my $constrained_elements;
    $multi->hide("compara", "constrained_element");
    foreach my $segment (@{$orig_ce->alignment_segments}) {
        my ($this_dnafrag_id, $this_dnafrag_start, $this_dnafrag_end, $this_dnafrag_strand, $species, $this_seq_region) = @$segment;
        my $ce_element = new Bio::EnsEMBL::Compara::ConstrainedElement(
                   -adaptor => $constrained_element_adaptor,
                   -reference_dnafrag_id => $this_dnafrag_id,
                   -start => $this_dnafrag_start,
                   -end => $this_dnafrag_end,
                   -strand => $this_dnafrag_strand,
                   -score => $score,
                   -p_value => $p_value);
        push(@$constrained_element_block, $ce_element);
    }
    push(@$constrained_elements, $constrained_element_block);

    $constrained_element_adaptor->store($method_link_species_set, $constrained_elements);

    my $new_ce = $constrained_element_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($method_link_species_set, $dnafrag)->[0];

    #Can only check a few values
    is($new_ce->p_value, $orig_ce->p_value, "check p_value");
    is($new_ce->score, $orig_ce->score, "check score");
    is($new_ce->method_link_species_set_id, $orig_ce->method_link_species_set_id, "check mlss_id");

    $multi->restore();
    done_testing();
};

subtest "Test  Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor->delete_by_dbID method", sub {
    my ($num_of_constrained_elements_with_id) = count_rows($compara_dba, "constrained_element", "WHERE constrained_element_id=?", [$constrained_element_id]);

    $multi->save("compara", "constrained_element");

    $constrained_element_adaptor->delete_by_dbID($constrained_element_id);
    my ($new_num_of_constrained_elements_with_id) = count_rows($compara_dba, "constrained_element", "WHERE constrained_element_id=?", [$constrained_element_id]);

    is($new_num_of_constrained_elements_with_id, 0, "check number of constrained elements");

    $multi->restore();
    done_testing();
};

subtest "Test  Bio::EnsEMBL::Compara::DBSQL::ConstrainedElementAdaptor->delete_by_MethodLinkSpeciesSet method", sub {
    my $num_of_constrained_elements_with_id = count_rows($compara_dba, "constrained_element", "WHERE method_link_species_set_id=?", [$method_link_species_set_id]);

    $multi->save("compara", "constrained_element");

    $constrained_element_adaptor->delete_by_MethodLinkSpeciesSet($method_link_species_set);
    my $new_num_of_constrained_elements_with_id = count_rows($compara_dba, "constrained_element", "WHERE method_link_species_set_id=?", [$method_link_species_set_id]);

    is($new_num_of_constrained_elements_with_id, 0, "check number of constrained elements");

    $multi->restore();
    done_testing();
};


sub load_pipeline_tables {
    my ($compara_dba, $table_name) = @_;
    my $ensembl_root_dir =  $ENV{ENSEMBL_CVS_ROOT_DIR};

    #first check if table is present
    my $sql_helper = $compara_dba->dbc->sql_helper;
    my $create_table = $sql_helper->execute(-SQL => "SHOW TABLES LIKE '%" . $table_name . "%'")->[0][0];
    
    unless ($create_table) {
        my $db_conn = sprintf "mysql -u %s %s -h %s -P%d %s", $compara_dba->dbc->user, ($compara_dba->dbc->pass ? "-p".$compara_dba->dbc->pass : ''), $compara_dba->dbc->host, $compara_dba->dbc->port, $compara_dba->dbc->dbname;
    
        `sed 's/ENGINE=InnoDB/ENGINE=MyISAM/g' $ensembl_root_dir/ensembl-compara/sql/pipeline-tables.sql | $db_conn`;
    }
    
}

done_testing();
