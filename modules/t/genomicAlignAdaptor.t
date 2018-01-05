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
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

my $multi = Bio::EnsEMBL::Test::MultiTestDB->new( "multi" );

my $compara_db = $multi->get_DBAdaptor( "compara" );
  
my $genomic_align;
my $genomic_align_block;
my $all_genomic_aligns;
my $genomic_align_adaptor = $compara_db->get_GenomicAlignAdaptor();
my $dnafrag_adaptor = $compara_db->get_DnaFragAdaptor();

my $sth;
my ($ga_id, $gab_id, $mlss_id, $df_id, $dfs, $dfe, $cg, $visible, $node_id);
my ($ga_id1, $gab_id1, $mlss_id1, $df_id1, $dfs1, $dfe1, $dfst1, $cg1, $node_id1, $visible1,
    $ga_id2, $gab_id2, $mlss_id2, $df_id2, $dfs2, $dfe2, $dfst2, $cg2, $node_id2, $visible2);

    $sth = $compara_db->dbc->prepare("SELECT
      genomic_align_id, genomic_align_block_id, method_link_species_set_id, dnafrag_id,
      dnafrag_start, dnafrag_end, visible, node_id, cigar_line
    FROM genomic_align WHERE dnafrag_strand = 1 AND node_id is not NULL LIMIT 1");
    $sth->execute();
    ($ga_id, $gab_id, $mlss_id, $df_id, $dfs, $dfe, $visible, $node_id, $cg) = $sth->fetchrow_array();
    $sth->finish();


subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor fetch_by_dbID($ga_id) method" , sub {

    my $genomic_align = $genomic_align_adaptor->fetch_by_dbID($ga_id);

    isa_ok($genomic_align, "Bio::EnsEMBL::Compara::GenomicAlign", "check object");
    is($genomic_align->adaptor, $genomic_align_adaptor, "adaptor");
    is($genomic_align->dbID, $ga_id, "dbID");
    is($genomic_align->genomic_align_block_id, $gab_id, "genomic_align_block_id");
    is($genomic_align->method_link_species_set_id, $mlss_id, "method_link_species_set_id");
    is($genomic_align->dnafrag_id, $df_id, "dnafrag_id");
    is($genomic_align->dnafrag_start, $dfs, "dnafrag_start");
    is($genomic_align->dnafrag_end, $dfe, "dnafrag_end");
    is($genomic_align->dnafrag_strand, 1, "dnafrag_strand");
    is($genomic_align->cigar_line, $cg, "cigar_line");
    is($genomic_align->visible, $visible, "visible");
    is($genomic_align->node_id, $node_id, "node_id");

    done_testing();
};

subtest "Test  Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor::fetch_by_dbID reverse strand", sub {
    $sth = $compara_db->dbc->prepare("SELECT
      genomic_align_id, genomic_align_block_id, method_link_species_set_id, dnafrag_id,
      dnafrag_start, dnafrag_end, visible, node_id, cigar_line
    FROM genomic_align WHERE dnafrag_strand = -1 AND node_id is not NULL LIMIT 1");
    $sth->execute();
    ($ga_id, $gab_id, $mlss_id, $df_id, $dfs, $dfe, $visible, $node_id,$cg) = $sth->fetchrow_array();
    $sth->finish();
    
    $genomic_align = $genomic_align_adaptor->fetch_by_dbID($ga_id);
    isa_ok($genomic_align,"Bio::EnsEMBL::Compara::GenomicAlign", "check object");
    is($genomic_align->adaptor, $genomic_align_adaptor, "adaptor");
    is($genomic_align->dbID, $ga_id, "dbID");
    is($genomic_align->genomic_align_block_id, $gab_id, "genomic_align_block_id");
    is($genomic_align->method_link_species_set_id, $mlss_id, "method_link_species_set_id");
    is($genomic_align->dnafrag_id, $df_id, "dnafrag_id");
    is($genomic_align->dnafrag_start, $dfs, "dnafrag_start");
    is($genomic_align->dnafrag_end, $dfe, "dnafrag_end");
    is($genomic_align->dnafrag_strand, -1, "dnafrag_strand");
    is($genomic_align->cigar_line, $cg, "cigar_line");
    is($genomic_align->visible, $visible, "visible");
    is($genomic_align->node_id, $node_id, "node_id");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor::fetch_all_by_GenomicAlignBlock", sub {
    $sth = $compara_db->dbc->prepare("
    SELECT
      ga1.genomic_align_id, ga1.genomic_align_block_id, ga1.method_link_species_set_id,
      ga1.dnafrag_id, ga1.dnafrag_start, ga1.dnafrag_end, ga1.dnafrag_strand,
      ga1.cigar_line, ga1.node_id, ga1.visible,
      ga2.genomic_align_id, ga2.genomic_align_block_id, ga2.method_link_species_set_id,
      ga2.dnafrag_id, ga2.dnafrag_start, ga2.dnafrag_end, ga2.dnafrag_strand,
      ga2.cigar_line, ga2.node_id, ga2.visible
    FROM genomic_align ga1, genomic_align ga2
    WHERE ga1.genomic_align_block_id = ga2.genomic_align_block_id and ga1.genomic_align_id != ga2.genomic_align_id LIMIT 1");
    $sth->execute();
    ($ga_id1, $gab_id1, $mlss_id1, $df_id1, $dfs1, $dfe1, $dfst1, $cg1, $node_id1, $visible1,
        $ga_id2, $gab_id2, $mlss_id2, $df_id2, $dfs2, $dfe2, $dfst2, $cg2, $node_id2, $visible2) =
          $sth->fetchrow_array();
    $sth->finish();
    
    #fetch_all_by_genomic_align_block_id
    $all_genomic_aligns = $genomic_align_adaptor->fetch_all_by_genomic_align_block_id($gab_id1);
    is(scalar(@$all_genomic_aligns), 2, "fetch_all_by_genomic_align_block_id($gab_id1) should return 2 objects");
    check_all_genomic_aligns($all_genomic_aligns);

    #fetch_all_by_genomic_align_block_id with species_list
    my $species_name = $all_genomic_aligns->[0]->genome_db->name;
    $all_genomic_aligns = $genomic_align_adaptor->fetch_all_by_genomic_align_block_id($gab_id1, [$species_name]);
    is(scalar(@$all_genomic_aligns), 1, "fetch_all_by_genomic_align_block_id($gab_id1, [$species_name]) should return 1 object");
    check_all_genomic_aligns($all_genomic_aligns);
    
    #Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor::fetch_all_by_GenomicAlignBlock
    $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                                                                        -dbID=>$gab_id1,
                                                                        -adaptor=>$compara_db->get_GenomicAlignBlockAdaptor
                                                                       );
    $all_genomic_aligns = $genomic_align_adaptor->fetch_all_by_GenomicAlignBlock($genomic_align_block);
    is(scalar(@$all_genomic_aligns), 2, "fetch_all_by_GenomicAlignBlock(\$genomic_aling_block) should return 2 objects");
    check_all_genomic_aligns($all_genomic_aligns);

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor::fetch_all_by_node_id", sub {
    $sth = $compara_db->dbc->prepare("
    SELECT node_id, count(*) FROM genomic_align WHERE node_id IS NOT NULL GROUP BY node_id HAVING count(*) > 1 LIMIT 1");
    $sth->execute();
    my ($node_id, $count) = $sth->fetchrow_array();
    $sth->finish();

    $all_genomic_aligns = $genomic_align_adaptor->fetch_all_by_node_id($node_id);
    is(@$all_genomic_aligns, $count, "count");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor::retrieve_all_direct_attributes", sub {

    my $genomic_align = $genomic_align_adaptor->fetch_by_dbID($ga_id);
    my $attribs = $genomic_align_adaptor->retrieve_all_direct_attributes($genomic_align);
    
    is($attribs->adaptor, $genomic_align_adaptor, "adaptor");
    is($attribs->dbID, $ga_id, "dbID");
    is($attribs->genomic_align_block_id, $gab_id, "genomic_align_block_id");
    is($attribs->method_link_species_set_id, $mlss_id, "method_link_species_set_id");
    is($attribs->dnafrag_id, $df_id, "dnafrag_id");
    is($attribs->dnafrag_start, $dfs, "dnafrag_start");
    is($attribs->dnafrag_end, $dfe, "dnafrag_end");
    is($attribs->dnafrag_strand, -1, "dnafrag_strand");
    is($attribs->cigar_line, $cg, "cigar_line");
    is($attribs->visible, $visible, "visible");
    is($attribs->node_id, $node_id, "node_id");

    done_testing();
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor count_by_mlss_id($mlss_id1) method" , sub {

    my $c = $genomic_align_adaptor->count_by_mlss_id($mlss_id1);
    is($c, 728, 'count_by_mlss_id');
};

subtest "Test Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor::store", sub {
    
    my $orig_genomic_align = $genomic_align_adaptor->fetch_by_dbID($ga_id);
    my $genomic_align = $orig_genomic_align->copy(); #Need to copy if I'm to use is_deeply to do a compare since storing populates more fields

    $multi->hide("compara", "genomic_align");
    
    my $sth = $compara_db->dbc->prepare("select * from genomic_align");
    $sth->execute;
    is($sth->rows, 0, "Checking that there is no entries left in the <genomic_align> table after hiding it");

    $genomic_align_adaptor->store([$genomic_align]);

    $sth->execute;
    is($sth->rows, 1, "Checking that there is 1 entry in the <genomic_align> table after store");

    my $new_genomic_align = $genomic_align_adaptor->fetch_by_dbID($ga_id);
    is_deeply($orig_genomic_align, $new_genomic_align);

    $genomic_align_adaptor->delete_by_genomic_align_block_id($genomic_align->genomic_align_block_id);

    $sth->execute;
    is($sth->rows, 0, "Checking that there is 0 entries in the <genomic_align> table after delete_by_genomic_align_block");
       
    $multi->restore();
    done_testing();
};

done_testing();


sub check_all_genomic_aligns {
  my ($all_genomic_aligns) = @_;

  foreach my $this_genomic_align (@{$all_genomic_aligns}) {
    if ($this_genomic_align->dbID == $ga_id1) {
      is($this_genomic_align->dbID, $ga_id1);
      is($this_genomic_align->adaptor, $genomic_align_adaptor, "unexpected genomic_align_adaptor");
      is($this_genomic_align->genomic_align_block_id, $gab_id1);
      is($this_genomic_align->method_link_species_set_id, $mlss_id1);
      is($this_genomic_align->dnafrag_id, $df_id1);
      is($this_genomic_align->dnafrag_start, $dfs1);
      is($this_genomic_align->dnafrag_end, $dfe1);
      is($this_genomic_align->dnafrag_strand, $dfst1);
      is($this_genomic_align->cigar_line, $cg1);
      is($this_genomic_align->node_id, $node_id2);
      is($this_genomic_align->visible, $visible2);
    } elsif ($this_genomic_align->dbID == $ga_id2) {
      is($this_genomic_align->dbID, $ga_id2);
      is($this_genomic_align->adaptor, $genomic_align_adaptor, "unexpected genomic_align_adaptor");
      is($this_genomic_align->genomic_align_block_id, $gab_id2);
      is($this_genomic_align->method_link_species_set_id, $mlss_id2);
      is($this_genomic_align->dnafrag_id, $df_id2);
      is($this_genomic_align->dnafrag_start, $dfs2);
      is($this_genomic_align->dnafrag_end, $dfe2);
      is($this_genomic_align->dnafrag_strand, $dfst2);
      is($this_genomic_align->cigar_line, $cg2);
      is($this_genomic_align->node_id, $node_id2);
      is($this_genomic_align->visible, $visible2);
    } else {
      is(0, 1, "unexpected genomic_align->dbID (".$this_genomic_align->dbID.")");
      is($this_genomic_align->adaptor, $genomic_align_adaptor, "unexpected genomic_align_adaptor");
      is($this_genomic_align->genomic_align_block_id, -1);
      is($this_genomic_align->method_link_species_set_id, -1);
      is($this_genomic_align->dnafrag_id, -1);
      is($this_genomic_align->dnafrag_start, -1);
      is($this_genomic_align->dnafrag_end, -1);
      is($this_genomic_align->dnafrag_strand, 0);
      #is($this_genomic_align->level_id, -1);
      is($this_genomic_align->cigar_line, "UNKNOWN!!!");
    }
  }
}

