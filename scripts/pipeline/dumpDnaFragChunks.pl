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

use DBI;
use Getopt::Long;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;


# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

GetOptions(
    'help'          => \$self->{'help'},
    'url=s'         => \$self->{'url'},
    'chunkset=s'    => \$self->{'chunkSetID'},
);

$self->{'dnafrag_chunk_ids'} = [@ARGV];

if ($self->{'help'}) { usage(); }
unless ($self->{'url'}) { usage(); }


$self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -URL => $self->{'url'} );

my $chunkDBA = $self->{'comparaDBA'}->get_DnaFragChunkAdaptor;

foreach my $chunk_id (@{$self->{'dnafrag_chunk_ids'}}) {
  print("dump sequence for dnafrag_chunk_id=$chunk_id\n");
  my $chunk = $chunkDBA->fetch_by_dbID($chunk_id);
  dumpChunkToCWD($chunk);
}

dumpChunkSetToWorkdir($self, $self->{'chunkSetID'});

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "dumpDnaFragChunks.pl [options] <dnafrag_chunk_id list>\n";
  print "  -help           : print this help\n";
  print "  -url <url>      : url pointing to compara database\n";
  print "  -chunkset <id>  : subset_id for chunk set\n";
  print "dumpDnaFragChunks.pl v1.1\n";
  
  exit(1);  
}


sub dumpChunkToCWD
{
  my $chunk = shift;

  my $fastafile = "chunk_" . $chunk->dbID . ".fasta";
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if(-e $fastafile);
  #print("fastafile = '$fastafile'\n");

  my $bioseq = $chunk->bioseq;
  unless($bioseq) {
    #printf("fetching chunk %s on-the-fly\n", $chunk->display_id);
    my $starttime = time();
    $bioseq = $chunk->bioseq;
    #print STDERR (time()-$starttime), " secs to fetch chunk seq\n";
    $chunk->sequence($bioseq->seq);
  }

  my $output_seq = Bio::SeqIO->new( -file => ">$fastafile", -format => 'Fasta');
  $output_seq->write_seq($bioseq);

  return $fastafile
}


sub dumpChunkToSeqIO
{
  my $chunk = shift;
  my $output_seqIO = shift;

  my $bioseq = $chunk->bioseq;
  unless($bioseq) {
    #printf("fetching chunk %s on-the-fly\n", $chunk->display_id);
    my $starttime = time();
    $bioseq = $chunk->bioseq;
    #print STDERR (time()-$starttime), " secs to fetch chunk seq\n";
    $chunk->sequence($bioseq->seq);
  }

  $output_seqIO->write_seq($bioseq);
}


sub dumpChunkSetToWorkdir
{
  my $self      = shift;
  my $chunkSetID   = shift;

  return unless($chunkSetID);

  my $chunkSet = $self->{'comparaDBA'}->get_DnaFragChunkSetAdaptor->fetch_by_dbID($chunkSetID);

  my $fastafile = "chunk_set_". $chunkSet->dbID .".fasta";
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if(-e $fastafile);
  #print("fastafile = '$fastafile'\n");

  my $output_seq = Bio::SeqIO->new( -file => ">$fastafile", -format => 'Fasta');

  my $chunk_array = $chunkSet->get_all_DnaFragChunks;
  printf("dumpChunkSetToWorkdir : %s : %d chunks\n", $fastafile, $chunkSet->count());

  foreach my $chunk (@$chunk_array) {
    printf("  writing chunk %s\n", $chunk->display_id);
    my $bioseq = $chunk->bioseq;
    $output_seq->write_seq($bioseq);
  }

  return $fastafile
}



