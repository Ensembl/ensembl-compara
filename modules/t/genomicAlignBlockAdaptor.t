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

my $species = [
        "homo_sapiens",
        "felis_catus",
    ];


#####################################################################
## Connect to the test database using the MultiTestDB.conf file

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );
my $compara_db_adaptor = $multi->get_DBAdaptor( "compara" );
my $genome_db_adaptor = $compara_db_adaptor->get_GenomeDBAdaptor();


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

my $genomic_align_adaptor = $compara_db_adaptor->get_GenomicAlignAdaptor();
my $genomic_align_block_adaptor = $compara_db_adaptor->get_GenomicAlignBlockAdaptor();
my $method_link_species_set_adaptor = $compara_db_adaptor->get_MethodLinkSpeciesSetAdaptor();
my $dnafrag_adaptor = $compara_db_adaptor->get_DnaFragAdaptor();


#####################################################################
##  DATA USED TO TEST API
##

my $all_genomic_align_blocks;

my $sth = $compara_db_adaptor->dbc->prepare("
    SELECT
      ga1.genomic_align_id, ga2.genomic_align_id, gab.genomic_align_block_id,
      gab.method_link_species_set_id, gab.score, gab.perc_id, gab.length
    FROM genomic_align ga1, genomic_align ga2, genomic_align_block gab,
      dnafrag df, genome_db gdb
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id
      and ga1.genomic_align_id != ga2.genomic_align_id
      and ga1.genomic_align_block_id = gab.genomic_align_block_id
      and ga1.cigar_line LIKE \"\%D\%\" and ga2.cigar_line LIKE \"\%D\%\" 
      and ga1.dnafrag_strand = 1 and ga2.dnafrag_strand = 1 and
      ga1.dnafrag_id = df.dnafrag_id and df.genome_db_id = gdb.genome_db_id and
      gdb.name = 'homo_sapiens' LIMIT 1");
$sth->execute();
my ($genomic_align_1_dbID, $genomic_align_2_dbID, $genomic_align_block_id,
    $method_link_species_set_id, $score, $perc_id, $length) =
    $sth->fetchrow_array();
$sth->finish();

my $genomic_align_blocks;
my $genomic_align_block;
my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
my $genomic_align_1 = $genomic_align_adaptor->fetch_by_dbID($genomic_align_1_dbID);
my $genomic_align_2 = $genomic_align_adaptor->fetch_by_dbID($genomic_align_2_dbID);
my $genomic_align_array = [$genomic_align_1, $genomic_align_2];

my $slice_adaptor = $species_db_adaptor->{$genomic_align_1->dnafrag->genome_db->name}->get_SliceAdaptor();

my $slice_coord_system_name = $genomic_align_1->dnafrag->coord_system_name;
my $slice_seq_region_name = $genomic_align_1->dnafrag->name;
my $slice_start = $genomic_align_1->dnafrag_start;
my $slice_end = $genomic_align_1->dnafrag_end;
my $slice = $slice_adaptor->fetch_by_region($slice_coord_system_name,$slice_seq_region_name,$slice_start,$slice_end);

my $dnafrag_id = $compara_db_adaptor->dbc->db_handle->selectrow_array("
    SELECT dnafrag_id FROM dnafrag df, genome_db gdb
    WHERE df.genome_db_id = gdb.genome_db_id
      and gdb.name = \"homo_sapiens\"
      and df.name = \"$slice_seq_region_name\"
      and df.coord_system_name = \"$slice_coord_system_name\"");
my $dnafrag_start = $slice_start;
my $dnafrag_end = $slice_end;

my $all_genomic_align_block_ids = $compara_db_adaptor->dbc->db_handle->selectcol_arrayref("
    SELECT genomic_align_block_id
    FROM genomic_align ga
    WHERE method_link_species_set_id = $method_link_species_set_id
      and dnafrag_id = $dnafrag_id
      and dnafrag_end >= $dnafrag_start
      and dnafrag_start <= $dnafrag_end");


##
#####################################################################

# 
#
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->fetch_by_dbID method", sub {
  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  isa_ok($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignBlock", "check object");
  is($genomic_align_block->dbID, $genomic_align_block_id);
  is($genomic_align_block->adaptor, $genomic_align_block_adaptor);
  is($genomic_align_block->method_link_species_set_id, $method_link_species_set_id);
  is($genomic_align_block->method_link_species_set->dbID, $method_link_species_set_id);
  is($genomic_align_block->score, $score);
  is($genomic_align_block->perc_id, $perc_id);
  is($genomic_align_block->length, $length);
  is(scalar(@{$genomic_align_block->genomic_align_array}), scalar(@$genomic_align_array));
  do {
    my $all_fails;
    foreach my $this_genomic_align (@{$genomic_align_block->genomic_align_array}) {
      my $fail = $this_genomic_align->dbID;
      foreach my $that_genomic_align (@$genomic_align_array) {
        if ($that_genomic_align->dbID == $this_genomic_align->dbID) {
          $fail = undef;
          last;
        }
      }
      $all_fails .= " <$fail> " if ($fail);
    }
    is($all_fails, undef,
        "Trying to get genomic_align_array from the database (returns the unexpected genomic_align_id)");
  };
  done_testing();
};

# 
#
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->fetch_all_by_MethodLinkSpeciesSet_Slice method", sub {
    my $slice = $slice_adaptor->fetch_by_region(
          $slice_coord_system_name,
          $slice_seq_region_name,
          $slice_start,
          $slice_end
      );

  $all_genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
      $method_link_species_set, $slice);
  do {
    my $all_fails;
    foreach my $this_genomic_align_block (@{$all_genomic_align_blocks}) {
      my $fail = $this_genomic_align_block->dbID;
      foreach my $that_genomic_align_block_id (@$all_genomic_align_block_ids) {
        if ($that_genomic_align_block_id == $this_genomic_align_block->dbID) {
          $fail = undef;
          last;
        }
      }
      $all_fails .= " <$fail> " if ($fail);
    }
    is($all_fails, undef);
  };
    done_testing();
};

# 
#
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag method", sub {
  my $all_genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
          $method_link_species_set,
          $dnafrag_adaptor->fetch_by_dbID($dnafrag_id),
          $dnafrag_start,
          $dnafrag_end
      );
  do {
    my $all_fails;
    foreach my $this_genomic_align_block (@{$all_genomic_align_blocks}) {
      my $fail = $this_genomic_align_block->dbID;
      foreach my $that_genomic_align_block_id (@$all_genomic_align_block_ids) {
        if ($that_genomic_align_block_id == $this_genomic_align_block->dbID) {
          $fail = undef;
          last;
        }
      }
      $all_fails .= " <$fail> " if ($fail);
    }
    is($all_fails, undef);
  };
  done_testing();
};

# 
#
# 
subtest "Test restrict option of the fetching methods", sub {
  my $all_genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
          $method_link_species_set,
          $genomic_align_1->dnafrag,
          $genomic_align_1->dnafrag_start,
          $genomic_align_1->dnafrag_end
      );
  do {
    my $aligned_seq = $all_genomic_align_blocks->[0]->get_all_non_reference_genomic_aligns()->[0]->aligned_sequence();
    my ($seq, $gap) = $aligned_seq =~ /^(\w+)(\-+)/;
    $aligned_seq = substr($all_genomic_align_blocks->[0]->reference_genomic_align()->aligned_sequence(), 0, length($seq));
    my $nucl = $aligned_seq =~ tr/ACGTNacgtn/ACGTacgtn/;
    $all_genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
            $method_link_species_set,
            $genomic_align_1->dnafrag,
            $genomic_align_1->dnafrag_start + $nucl - 1,
            $genomic_align_1->dnafrag_start + $nucl + length($gap),
            undef, undef, "restrict"
        );
    is(length($all_genomic_align_blocks->[0]->reference_genomic_align()->aligned_sequence()), length($gap) + 2,
        "Check restriction 1 nucl before and after gap in secondary seq");
    $all_genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
            $method_link_species_set,
            $genomic_align_1->dnafrag,
            $genomic_align_1->dnafrag_start + $nucl,
            $genomic_align_1->dnafrag_start + $nucl + length($gap) - 1,
            undef, undef, "restrict"
        );
    is(scalar(@$all_genomic_align_blocks), 0,
        "Check restriction when gap in secondary seq: block should not be returned");

    my $slice = $slice_adaptor->fetch_by_region(
            $genomic_align_1->dnafrag->coord_system_name,
            $genomic_align_1->dnafrag->name,
            $genomic_align_1->dnafrag_start + $nucl - 1,
            $genomic_align_1->dnafrag_start + $nucl + length($gap),
        );

    $all_genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
            $method_link_species_set,
            $slice,
            undef, undef, "restrict"
        );
    is(length($all_genomic_align_blocks->[0]->reference_genomic_align()->aligned_sequence()), length($gap) + 2,
        "Check restriction 1 nucl before and after gap in secondary seq");
    $slice = $slice_adaptor->fetch_by_region(
            $genomic_align_1->dnafrag->coord_system_name,
            $genomic_align_1->dnafrag->name,
            $genomic_align_1->dnafrag_start + $nucl,
            $genomic_align_1->dnafrag_start + $nucl + length($gap) - 1 ,
        );
    $all_genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
            $method_link_species_set,
            $slice,
            undef, undef, "restrict"
        );
    is(scalar(@$all_genomic_align_blocks), 0,
        "Check restriction when gap in secondary seq: block should not be returned");
  };
  done_testing();
};

# 
#
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->retrieve_all_direct_attributes method", sub {
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -dbID => $genomic_align_block_id,
          -adaptor => $genomic_align_block_adaptor
      );
  isa_ok($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignBlock", "check object");
  $genomic_align_block_adaptor->retrieve_all_direct_attributes($genomic_align_block);
  is($genomic_align_block->dbID, $genomic_align_block_id);
  is($genomic_align_block->adaptor, $genomic_align_block_adaptor);
  is($genomic_align_block->method_link_species_set_id, $method_link_species_set_id);
  is($genomic_align_block->score, $score);
  is($genomic_align_block->perc_id, $perc_id);
  is($genomic_align_block->length, $length);

  done_testing();
};

# 
#
# 
subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->store method", sub {
  $genomic_align_1->dbID(0);
  $genomic_align_1->genomic_align_block_id(0);
  $genomic_align_2->dbID(0);
  $genomic_align_2->genomic_align_block_id(0);
  
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -adaptor => $genomic_align_block_adaptor,
          -method_link_species_set_id => $method_link_species_set_id,
          -score => $score,
          -length => $length,
          -perc_id => $perc_id,
          -genomic_align_array => $genomic_align_array
      );
  isa_ok($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignBlock", "check object");
  $genomic_align_block_adaptor->store($genomic_align_block);
  ok($genomic_align_block->dbID);
  isnt($genomic_align_block->dbID, $genomic_align_block_id);
  is($genomic_align_block->adaptor, $genomic_align_block_adaptor);
  is($genomic_align_block->method_link_species_set_id, $method_link_species_set_id);
  is($genomic_align_block->method_link_species_set->dbID, $method_link_species_set_id);
  is($genomic_align_block->score, $score);
  is($genomic_align_block->perc_id, $perc_id);
  is($genomic_align_block->length, $length);
  is(scalar(@{$genomic_align_block->genomic_align_array}), scalar(@$genomic_align_array));
  do {
    my $all_fails;
    foreach my $this_genomic_align (@{$genomic_align_block->genomic_align_array}) {
      my $fail = $this_genomic_align->dbID;
      foreach my $that_genomic_align (@$genomic_align_array) {
        if ($that_genomic_align->dbID == $this_genomic_align->dbID) {
          $fail = undef;
          last;
        }
      }
      $all_fails .= " <$fail> " if ($fail);
    }
    is($all_fails, undef,
        "Trying to get genomic_align_array from the database (returns the unexpected genomic_align_id)");
  };

  done_testing();
};

$genomic_align_block_id = $genomic_align_block->dbID;
subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor->delete method", sub {
  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  isa_ok($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignBlock", "check object");
  $genomic_align_block = $genomic_align_block_adaptor->delete_by_dbID($genomic_align_block_id);
  $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID($genomic_align_block_id);
  ok(!$genomic_align_block);

  done_testing();
};

done_testing();

