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

use Bio::EnsEMBL::Compara::DnaFragRegion;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $dnafrag_region_adaptor = $compara_db_adaptor->get_DnaFragRegionAdaptor();
my $dnafrag_adaptor = $compara_db_adaptor->get_DnaFragAdaptor();

my $homo_sapiens = Bio::EnsEMBL::Test::MultiTestDB->new( "homo_sapiens" );

my $sth = $compara_db_adaptor->dbc->prepare("SELECT synteny_region_id, genome_db.name, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand FROM dnafrag_region JOIN dnafrag USING (dnafrag_id) JOIN genome_db USING (genome_db_id) LIMIT 1");

$sth->execute();
my ($synteny_region_id, $genome_db_name, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand) = $sth->fetchrow_array();
$sth->finish();

my $core_dba = Bio::EnsEMBL::Test::MultiTestDB->new($genome_db_name);

my $dnafrag = $dnafrag_adaptor->fetch_by_dbID($dnafrag_id);

subtest "Test Bio::EnsEMBL::Compara::DnaFragRegion new(void) method", sub {
  my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion();
  isa_ok($dnafrag_region, "Bio::EnsEMBL::Compara::DnaFragRegion", "check object");
  done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DnaFragRegion new(ALL) method", sub {
  my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion(-adaptor => $dnafrag_region_adaptor,
                                                                -synteny_region_id => $synteny_region_id,
                                                                -dnafrag_id        => $dnafrag_id,
                                                                -dnafrag_start     => $dnafrag_start,
                                                                -dnafrag_end       => $dnafrag_end,
                                                                -dnafrag_strand    => $dnafrag_strand);

  isa_ok($dnafrag_region, "Bio::EnsEMBL::Compara::DnaFragRegion", "check object");

  is($dnafrag_region->adaptor, $dnafrag_region_adaptor, "adaptor"); 
  is($dnafrag_region->synteny_region_id, $synteny_region_id, "synteny_region_id"); 
  is($dnafrag_region->dnafrag_id, $dnafrag_id, "dnafrag_id"); 
  is($dnafrag_region->dnafrag_start, $dnafrag_start, "dnafrag_start"); 
  is($dnafrag_region->dnafrag_end, $dnafrag_end, "dnafrag_end"); 
  is($dnafrag_region->dnafrag_strand, $dnafrag_strand, "dnafrag_strand"); 

  done_testing();              
};

subtest "Test getter/setter Bio::EnsEMBL::Compara::DnaFragRegion methods", sub {
    my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion(-adaptor => $dnafrag_region_adaptor,
                                                                  -synteny_region_id => $synteny_region_id,
                                                                  -dnafrag_id        => $dnafrag_id,
                                                                  -dnafrag_start     => $dnafrag_start,
                                                                  -dnafrag_end       => $dnafrag_end,
                                                                  -dnafrag_strand    => $dnafrag_strand);

    ok(test_getter_setter($dnafrag_region, "adaptor", $dnafrag_region_adaptor));
    ok(test_getter_setter($dnafrag_region, "synteny_region_id", $synteny_region_id));
    ok(test_getter_setter($dnafrag_region, "dnafrag_id", $dnafrag_id));
    ok(test_getter_setter($dnafrag_region, "dnafrag_start", $dnafrag_start));
    ok(test_getter_setter($dnafrag_region, "dnafrag_end", $dnafrag_end));
    ok(test_getter_setter($dnafrag_region, "dnafrag_strand", $dnafrag_strand));

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DnaFragRegion::dnafrag method", sub {
    my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion(-adaptor => $dnafrag_region_adaptor,
                                                                  -dnafrag_id        => $dnafrag_id);

    ok(test_getter_setter($dnafrag_region, "dnafrag", $dnafrag));

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DnaFragRegion::slice method", sub {
    my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion(-adaptor => $dnafrag_region_adaptor,
                                                                  -dnafrag_id        => $dnafrag_id,
                                                                  -dnafrag_start     => $dnafrag_start,
                                                                  -dnafrag_end       => $dnafrag_end,
                                                                  -dnafrag_strand    => $dnafrag_strand);

    my $slice = $dnafrag_region->slice;
    isa_ok($slice, "Bio::EnsEMBL::Slice", "check object");
    is($slice->length, ($dnafrag_end-$dnafrag_start+1), "length");
    is($slice->seq_region_name, $dnafrag_region->dnafrag->name, "name");
    is($slice->coord_system->name, $dnafrag_region->dnafrag->coord_system_name, "coord_system");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DnaFragRegion::genome_db method", sub {
    my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion(-adaptor => $dnafrag_region_adaptor,
                                                                  -dnafrag_id        => $dnafrag_id);

    my $genome_db = $dnafrag_region->genome_db;
    isa_ok($genome_db, "Bio::EnsEMBL::Compara::GenomeDB", "check object");
    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DnaFragRegion::length method", sub {

    #NB: need to set the dnafrag_start and dnafrag_end here or we get a length of 1. Not sure if should
    #add code to DnaFragRegion.pm to get the object if these are not set?
    my $dnafrag_region = new Bio::EnsEMBL::Compara::DnaFragRegion(-adaptor => $dnafrag_region_adaptor,
                                                                  -dnafrag_id        => $dnafrag_id,
                                                                  -dnafrag_start     => $dnafrag_start,
                                                                  -dnafrag_end       => $dnafrag_end);

    my $length = $dnafrag_region->length;
    is($length, ($dnafrag_end - $dnafrag_start + 1), "length");
    done_testing();
};

done_testing();
