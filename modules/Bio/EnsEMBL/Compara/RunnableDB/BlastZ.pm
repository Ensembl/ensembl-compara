#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BlastZ

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::BlastZ->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Pipeline::Runnable::Blast to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. A Bio::EnsEMBL::Pipeline::DBSQL::Obj is
required for databse access.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BlastZ;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Pipeline::Runnable::Blastz;
use Time::HiRes qw(time gettimeofday tv_interval);

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);
my $g_compara_BlastZ_workdir;

=head2 fetch_input
    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none
=cut

sub fetch_input {
  my( $self) = @_;

  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);

  print("input_id = ", $self->input_id,"\n");
  my $input_hash = eval($self->input_id);
  print("$input_hash\n");
  $self->throw("No input_id") unless defined($input_hash);
  my $qy_chunk_id = $input_hash->{'qyChunk'};
  my $db_chunk_id = $input_hash->{'dbChunk'};

  my $qyChunk = $self->{'comparaDBA'}->get_DnaFragChunkAdaptor->fetch_by_dbID($qy_chunk_id);
  my $dbChunk = $self->{'comparaDBA'}->get_DnaFragChunkAdaptor->fetch_by_dbID($db_chunk_id);

  print("have chunks\n  ",$qyChunk->display_id,"\n  ", $dbChunk->display_id,"\n");
  my $starttime = time();

  my $qySeq = $qyChunk->bioseq;
  unless($qySeq) {
    $qySeq = $qyChunk->fetch_masked_sequence(2);  #soft masked
    print STDERR (time()-$starttime), " secs to fetch qyChunk seq\n";
  }

  my $dbSeq = $dbChunk->bioseq;
  unless($dbSeq) {
    $dbSeq = $dbChunk->fetch_masked_sequence(2);  #soft masked
    print STDERR (time()-$starttime), " secs to fetch dbChunk seq\n";
  }

  #print("running with analysis '".$self->analysis->logic_name."'\n");
  my $runnable =  new Bio::EnsEMBL::Pipeline::Runnable::Blastz (
                  -query     => $qySeq,
                  -database  => $dbSeq,
                  -options   => 'T=2 H=2200');

  $self->runnable($runnable);
  return 1;
}


sub run
{
  my $self = shift;

  my $starttime = time();
  foreach my $runnable ($self->runnable) {
    throw("Runnable module not set") unless($runnable);
    $runnable->run();
  }
  print STDERR (time()-$starttime), " secs to BlastZ\n";
  return 1;
}


sub write_output {
  my( $self) = @_;

  #since the Blast runnable takes in analysis parameters rather than an
  #analysis object, it creates new Analysis objects internally
  #(a new one for EACH FeaturePair generated)
  #which are a shadow of the real analysis object ($self->analysis)
  #The returned FeaturePair objects thus need to be reset to the real analysis object
  foreach my $fp ($self->output) {
    if($fp->isa('Bio::EnsEMBL::FeaturePair')) {
      $fp->analysis($self->analysis);
      print STDOUT $fp->seqname."\t".$fp->start."\t".$fp->end."\t".$fp->hseqname."\t".$fp->hstart."\t".$fp->hend."\t".$fp->hstrand."\t".$fp->score."\t".$fp->percent_id."\t".$fp->cigar_string."\n";
    }
  }

  #$self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor->store($self->output);
}


sub global_cleanup {
  my $self = shift;
  if($g_compara_BlastZ_workdir) {
    unlink(<$g_compara_BlastZ_workdir/*>);
    rmdir($g_compara_BlastZ_workdir);
  }
  return 1;
}

##########################################
#
# internal methods
#
##########################################

# using the genome_db and longest peptides subset, create a fasta
# file which can be used as a blast database
sub dumpPeptidesToFasta
{
  my $self = shift;

  my $startTime = time();
  my $params = eval($self->analysis->parameters);
  my $genomeDB = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_dbID($params->{'genome_db_id'});
  
  # create logical path name for fastafile
  my $species = $genomeDB->name();
  $species =~ s/\s+/_/g;  # replace whitespace with '_' characters

  #create temp directory to hold fasta databases
  $g_compara_BlastZ_workdir = "/tmp/worker.$$/";
  mkdir($g_compara_BlastZ_workdir, 0777);
  
  my $fastafile = $g_compara_BlastZ_workdir.
                  $species . "_" .
                  $genomeDB->assembly() . ".fasta";
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if(-e $fastafile);
  print("fastafile = '$fastafile'\n");

  # write fasta file to local /tmp/disk
  my $subset   = $self->{'comparaDBA'}->get_SubsetAdaptor()->fetch_by_dbID($params->{'subset_id'});
  $self->{'comparaDBA'}->get_SubsetAdaptor->dumpFastaForSubset($subset, $fastafile);

  # configure the fasta file for use as a blast database file
  my $blastdb     = new Bio::EnsEMBL::Pipeline::Runnable::BlastDB (
      -dbfile     => $fastafile,
      -type       => 'PROTEIN');
  $blastdb->run;
  print("registered ". $blastdb->dbname . " for ".$blastdb->dbfile . "\n");

  printf("took %d secs to dump database to local disk\n", (time() - $startTime));

  return $fastafile
}

1;
