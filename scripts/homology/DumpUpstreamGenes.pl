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

use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::Seq;
use Bio::SeqIO;

my $upstream_length = 5000;
my $species_name;

GetOptions(
        'upstream_length=i' => \$upstream_length,
        'species_name=s'    => \$species_name,
);

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
        -host=>'ensembldb.ensembl.org',
        -user=>'anonymous', 
);

my $ma = $reg->get_adaptor('Multi', 'Compara', 'GeneMember');
my $ga = $reg->get_adaptor('Multi', 'Compara', 'GenomeDB');

my $gdb = $ga->fetch_by_registry_name($species_name);
my $gene_members = $ma->fetch_all_by_GenomeDB($gdb, 'ENSEMBLGENE');

foreach my $gene_member (@{$gene_members}) {
  
  my $ga = $gene_member->genome_db->db_adaptor->get_GeneAdaptor;
  my $gene = $ga->fetch_by_stable_id($gene_member->stable_id);
  $gene->transform('toplevel');
  my $sa = $gene_member->genome_db->db_adaptor->get_SliceAdaptor;
  my $slice;
  if ($gene->strand > 0) {
    $slice = $sa->fetch_by_region('toplevel',$gene->slice->seq_region_name,$gene->seq_region_start-$upstream_length,$gene->seq_region_start-1);
  } else {
    $slice = $sa->fetch_by_region('toplevel',$gene->slice->seq_region_name,$gene->seq_region_end+1, $gene->seq_region_end+$upstream_length,-1);
  }
    
  my $seq = $slice->get_repeatmasked_seq->seq;

  foreach my $exon (@{$slice->get_all_Exons}) {
    my $length = $exon->end-$exon->start+1;
    my $padstr = 'N' x $length;
    substr ($seq,$exon->start,$length) = $padstr;
  }
  
  my $seqIO = Bio::SeqIO->newFh(-interleaved => 0,
                                -fh => \*STDOUT,
                                -format => "fasta",
                                -idlength => 20);
    
    
  my $bioseq = Bio::Seq->new( -display_id => $gene->stable_id . "_".$upstream_length ."bp_upstream",
                              -seq => $seq);

  print $seqIO $bioseq;
}
