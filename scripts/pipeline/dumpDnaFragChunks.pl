#!/usr/local/ensembl/bin/perl -w

use strict;
use Switch;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Analysis;
use Bio::EnsEMBL::Pipeline::Rule;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Hive::URLFactory;


# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

my $conf_file;
my $help;

$self->{'dnafrag_chunk_ids'} = [];

parse_cmd_line($self);
          
if ($help) { usage(); }
unless ($self->{'url'}) { usage(); }


my $dba = Bio::EnsEMBL::Hive::URLFactory->fetch($self->{'url'}) if($self->{'url'});
print("$dba\n");
$self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$dba->dbc);

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

sub parse_cmd_line {
  my $self = shift;

  my $state=0;
  
  foreach my $token (@ARGV) {
    print("state=$state  token:'$token'\n");

    $state = 1 if($token =~ /^-/);
    switch($state) {
      case 0 #non parameter
        { push @{$self->{'dnafrag_chunk_ids'}}, $token; }
      case 1 {
        switch($token) {
          case '-url' {$state=10;}
          case '-chunkset' {$state=11;}
          else  {$state=0;}
        };}
      case 10 { $self->{'url'} = $token; $state=0; }
      case 11 { $self->{'chunkSetID'} = $token; $state=0; }
    }
    print("  state=$state\n");
    
  }
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

  open(OUTSEQ, ">$fastafile");
  my $output_seq = Bio::SeqIO->new( -fh =>\*OUTSEQ, -format => 'Fasta');
  $output_seq->write_seq($bioseq);
  close OUTSEQ;

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

  open(OUTSEQ, ">$fastafile")
    or $self->throw("Error opening $fastafile for write");
  my $output_seq = Bio::SeqIO->new( -fh =>\*OUTSEQ, -format => 'Fasta');

  my $chunk_array = $chunkSet->get_all_DnaFragChunks;
  printf("dumpChunkSetToWorkdir : %s : %d chunks\n", $fastafile, $chunkSet->count());

  foreach my $chunk (@$chunk_array) {
    printf("  writing chunk %s\n", $chunk->display_id);
    my $bioseq = $chunk->bioseq;
    $output_seq->write_seq($bioseq);
  }
  close OUTSEQ;

  return $fastafile
}



