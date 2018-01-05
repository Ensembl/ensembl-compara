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

#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_dba = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
my $constrained_element_adaptor = $compara_dba->get_ConstrainedElementAdaptor();
my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor();

my $this_species = "homo_sapiens";

my $species = [
        "homo_sapiens",
    ];

## Connect to core DB specified in the MultiTestDB.conf file
my $genome_dbs;
my $species_db_adaptor;
my $species_gdb;
my @test_dbs;

foreach my $this_species (@$species) {
    my $species_db = Bio::EnsEMBL::Test::MultiTestDB->new($this_species);
    $species_db_adaptor->{$this_species} = $species_db->get_DBAdaptor('core');
    my $species_gdb = $genome_db_adaptor->fetch_by_registry_name($this_species);
    $species_gdb->db_adaptor($species_db_adaptor->{$this_species});
    $genome_dbs->{$this_species} = $species_gdb;
    push @test_dbs, $species_db;
}

my ($constrained_element_id, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand, $method_link_species_set_id, $p_value,
     $score) = 
       $compara_dba->dbc->db_handle->selectrow_array("SELECT * FROM constrained_element LIMIT 1");

my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);

#Slice
my $slice_adaptor = $species_db_adaptor->{$this_species}->get_SliceAdaptor();

my $slice_coord_system_name = $dnafrag->coord_system_name;
my $slice_seq_region_name = $dnafrag->name;
my $slice_start = $dnafrag_start;
my $slice_end = $dnafrag_end;
my $slice = $slice_adaptor->fetch_by_region($slice_coord_system_name,$slice_seq_region_name,$slice_start,$slice_end);

subtest "Test Bio::EnsEMBL::Compara::ConstrainedElement new(void) method", sub {
        my $constrained_element = new Bio::EnsEMBL::Compara::ConstrainedElement();
        isa_ok($constrained_element, "Bio::EnsEMBL::Compara::ConstrainedElement", "check object");
        done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::ConstrainedElement new(ALL) method", sub {

    my $genome_db = $genome_dbs->{$this_species};

    my $alignment_segment = [$dnafrag_id, $dnafrag_start, $dnafrag_end, $genome_db->dbID, $dnafrag->name];

    my $alignment_segments = [$alignment_segment];
    my $ce = new Bio::EnsEMBL::Compara::ConstrainedElement(
                                                           -adaptor => $constrained_element_adaptor,
                                                           -dbID => $constrained_element_id,
                                                           -method_link_species_set => $method_link_species_set,
                                                           -alignment_segments => $alignment_segments,
                                                           -score => $score,
                                                           -p_value => $p_value,
                                                           -strand => $dnafrag_strand,
                                                           -start => $dnafrag_start,
                                                           -end => $dnafrag_end,
                                                           -reference_dnafrag_id => $dnafrag_id,
                                                           -slice => $slice,
                                                          );
    is($ce->adaptor, $constrained_element_adaptor, "adaptor");
    is($ce->dbID, $constrained_element_id, "dbID");
    is($ce->score, $score, "score");
    is($ce->p_value, $p_value, "p_value");
    is($ce->strand, $dnafrag_strand, "strand");
    is($ce->start, $dnafrag_start, "start");
    is($ce->end, $dnafrag_end, "end");
    is($ce->slice, $slice, "slice");
    is($ce->reference_dnafrag_id, $dnafrag_id, "dnafrag_id");
    is_deeply($ce->alignment_segments, $alignment_segments, "alignment_segments");

    done_testing();
};

subtest "Test getter/setter Bio::EnsEMBL::Compara::ConstrainedElement methods", sub {
     my $genome_db = $genome_dbs->{$this_species};

    my $alignment_segment = [$dnafrag_id, $dnafrag_start, $dnafrag_end, $genome_db->dbID, $dnafrag->name];

    my $alignment_segments = [$alignment_segment];
    my $ce = new Bio::EnsEMBL::Compara::ConstrainedElement(
                                                           -adaptor => $constrained_element_adaptor,
                                                           -dbID => $constrained_element_id,
                                                           -method_link_species_set => $method_link_species_set,
                                                           -alignment_segments => $alignment_segments,
                                                           -score => $score,
                                                           -p_value => $p_value,
                                                           -strand => $dnafrag_strand,
                                                           -start => $dnafrag_start,
                                                           -end => $dnafrag_end,
                                                           -reference_dnafrag_id => $dnafrag->dbID,
                                                          );

     ok(test_getter_setter($ce, "adaptor", $constrained_element_adaptor));
     ok(test_getter_setter($ce, "dbID", $constrained_element_id));
     ok(test_getter_setter($ce, "score", $score));
     ok(test_getter_setter($ce, "p_value", $p_value));
     ok(test_getter_setter($ce, "strand", $dnafrag_strand));
     ok(test_getter_setter($ce, "start", $dnafrag_start));
     ok(test_getter_setter($ce, "end", $dnafrag_end));
     ok(test_getter_setter($ce, "reference_dnafrag_id", $dnafrag_id));

    done_testing();
};

done_testing();
