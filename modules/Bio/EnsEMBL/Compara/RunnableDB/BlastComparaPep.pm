#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPep

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::BlastComparaPep->new ( 
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

package Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPep;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::RunnableDB;
use Bio::EnsEMBL::Pipeline::Runnable::Blast;
use Bio::EnsEMBL::Pipeline::Runnable::BlastDB;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::PeptideAlignFeatureAdaptor;
use Bio::EnsEMBL::Compara::Member;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);
my $g_BlastComparaPep_workdir;

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


  my $member_id  = $self->input_id;
  my $member     = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_dbID($member_id);
  $self->throw("No member in compara for member_id=$member_id") unless defined($member);
  #$member->print_member;

  
  my $bioseq     = $member->bioseq();
  $self->throw("Unable to make bioseq for member_id=$member_id") unless defined($bioseq);
  $self->query($bioseq);

  my ($thr, $thr_type, $options);
  my $p = eval($self->analysis->parameters);

  if (defined $p->{'-threshold'} && defined $p->{'-threshold_type'}) {
      $thr      = $p->{-threshold};
      $thr_type = $p->{-threshold_type};
  }
  else {
      $thr_type = 'PVALUE';
      $thr      = 1e-10;
  }
  if (defined $p->{'options'}) {
    $options = $p->{'options'};
    # print("!!!found my options : $options\n");
  }
  else {
    $options = '';
  }

  my $dbfile = $self->analysis->db_file;
#  $dbfile = $self->dumpPeptidesToFasta();
  

=head3
  my $stable_id  = $member->stable_id();
  my $logic_name = $self->analysis->logic_name();
  print("BlastComparaPep query='$stable_id'  anal='$logic_name'\n");
  my $seq_string = $member->sequence();
  print("  seq : $seq_string\n");
  my $options = $self->analysis->parameters;
  print("  option = '$options'\n");

  my $runnable = new Bio::EnsEMBL::Pipeline::Runnable::Blast(
      -query          => $bioseq,
      -database       => $self->analysis->db_file,
      -threshold      => 1e-10,
      -options        => "-filter none -span1 -postsw -V=20 -B=20 -sort_by_highscore -warnings -cpus 1",
      -threshold_type => "PVALUE",
      -program        => '/scratch/local/ensembl/bin/wublastp');
  $self->runnable($runnable);
=cut

  #print("running with analysis '".$self->analysis->logic_name."'\n");
  my $runnable = Bio::EnsEMBL::Pipeline::Runnable::Blast->new(
                     -query          => $self->query,
                     -database       => $dbfile,
                     -program        => $self->analysis->program_file,
                     -options        => $options,
                     -threshold      => $thr,
                     -threshold_type => $thr_type
                    );
  $dbfile =~ s/\/tmp\///g if($dbfile =~/\/tmp\//);
  $runnable->add_regex($dbfile, '^(\S+)\s*');
  $self->runnable($runnable);
  return 1;
}


sub run
{
  my $self = shift;
  #call superclasses run method
  return $self->SUPER::run();
}


sub write_output {
  my( $self) = @_;

  #since the Blast runnable takes in analysis parameters rather than an
  #analysis object, it creates new Analysis objects internally
  #(a new one for EACH FeaturePair generated)
  #which are a shadow of the real analysis object ($self->analysis)
  #The returned FeaturePair objects thus need to be reset to the real analysis object

  foreach my $feature ($self->output) {
    if($feature->isa('Bio::EnsEMBL::FeaturePair')) {
      $feature->analysis($self->analysis);
    }
  }

  $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor->store($self->output);
}


sub global_cleanup {
  my $self = shift;
  if($g_BlastComparaPep_workdir) {
    unlink(<$g_BlastComparaPep_workdir/*>);
    rmdir($g_BlastComparaPep_workdir);
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
  $g_BlastComparaPep_workdir = "/tmp/worker.$$/";
  mkdir($g_BlastComparaPep_workdir, 0777);
  
  my $fastafile = $g_BlastComparaPep_workdir.
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
