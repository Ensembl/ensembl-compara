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
my $blast = Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPep->new
 (
  -db      => $db,
  -input_id   => $input_id
  -analysis   => $analysis );
$blast->fetch_input(); #reads from DB
$blast->run();
$blast->output();
$blast->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Analysis::Runnable::Blast to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. A Bio::EnsEMBL::Analysis::DBSQL::Obj is
required for databse access.

=cut

=head1 CONTACT

  Contact Jessica Severin on module implemetation/design detail: jessica@ebi.ac.uk
  Contact Abel Ureta-Vidal on EnsEMBL/Compara: abel@ebi.ac.uk
  Contact Ewan Birney on EnsEMBL in general: birney@sanger.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BlastComparaPep;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Analysis::Runnable;
use Bio::EnsEMBL::Analysis::Runnable::Blast;
use Bio::EnsEMBL::Analysis::Tools::BPliteWrapper;
use Bio::EnsEMBL::Analysis::Tools::FilterBPlite;
use Bio::EnsEMBL::Hive::Process;
use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Hive::Process);

# 
# our @ISA = qw(Bio::EnsEMBL::Analysis::RunnableDB::Blast);

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

  throw("No input_id") unless defined($self->input_id);

  ## Get the query (corresponds to the member with a member_id = input_id
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);
  my $member_id = $self->input_id; 
  
  my $member = $self->{'comparaDBA'}->get_MemberAdaptor->fetch_by_dbID($member_id);
  throw("No member in compara for member_id = $member_id") unless defined($member);
  if (10 > $member->bioseq->length) {
	$self->input_job->update_status('DONE');
	throw("BLAST : Peptide is too short for BLAST");
  }

  my $query = $member->bioseq();  

  throw("Unable to make bioseq for member_id = $member_id") unless defined($query);

  ## Get the db_file (defined in the analysis)
  my $dbfile = $self->analysis->db_file;

  ## Define the filter from the parameters
  my ($thr, $thr_type, $options); 

  #my $p = eval($self->analysis->parameters); 
  my $p = eval($self->analysis->data);     

  if (defined $p->{'-threshold'} && defined $p->{'-threshold_type'}) {
      $thr      = $p->{-threshold};
      $thr_type = $p->{-threshold_type};
  } else {
      $thr_type = 'PVALUE';
      $thr      = 1e-10;
  }

  if (defined $p->{'options'}) { 
    $options = $p->{'options'}; 
  } else {
    $options = '';
  }

  ## Create a parser object. This Bio::EnsEMBL::Analysis::Tools::FilterBPlite
  ## object wraps the Bio::EnsEMBL::Analysis::Tools::BPliteWrapper which in
  ## turn wraps the Bio::EnsEMBL::Analysis::Tools::BPlite (a port of Ian
  ## Korf's BPlite from bioperl 0.7 into ensembl). This parser also filter
  ## the results according to threshold_type and threshold.
  my $regex = '^(\S+)\s*';
  if ($p->{'regex'}) {
    $regex = $p->{'regex'};
  }

  my $parser = Bio::EnsEMBL::Analysis::Tools::FilterBPlite->new(
          -regex => $regex,
          -query_type => "pep",
          -input_type => "pep",
          -threshold_type => $thr_type,
          -threshold => $thr,
      );

  ## Create the runnable with the previous parser. The filter is not required
  my $runnable = Bio::EnsEMBL::Analysis::Runnable::Blast->new(
        -query     => $query,
        -database  => $dbfile,
        -program   => $self->analysis->program_file,
        -analysis  => $self->analysis,
        -options   => $options,
        -parser    => $parser,
        -filter    => undef,
      );
  $self->runnable($runnable);

  return 1;
}


=head2 runnable

  Arg[1]     : (optional) Bio::EnsEMBL::Analysis::Runnable $runnable
  Example    : $self->runnable($runnable);
  Function   : Getter/setter for the runnable
  Returns    : Bio::EnsEMBL::Analysis::Runnable $runnable
  Exceptions : none

=cut

sub runnable {
  my $self = shift(@_);

  if (@_) {
    $self->{_runnable} = shift;
  }

  return $self->{_runnable};
}


=head2 run

  Arg[1]     : -none-
  Example    : $self->run;
  Function   : Runs the runnable set in fetch_input
  Returns    : 1 on succesfull completion
  Exceptions : dies if runnable throws an unexpected error

=cut

sub run {
  my $self = shift;

  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);

  ## call runnable run method in eval block
  eval { $self->runnable->run(); };
  ## Catch errors if any
  if ($@) {
    printf(STDERR ref($self->runnable)." threw exception:\n$@$_");
    if($@ =~ /"VOID"/) {
      printf(STDERR "this is OK: member_id=%d doesn't have sufficient structure for a search\n", $self->input_id);
    } else {
      die("$@$_");
    }
  }
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(0);

  return 1;
}


sub write_output {
  my( $self) = @_;

  #since the Blast runnable takes in analysis parameters rather than an
  #analysis object, it creates new Analysis objects internally
  #(a new one for EACH FeaturePair generated)
  #which are a shadow of the real analysis object ($self->analysis)
  #The returned FeaturePair objects thus need to be reset to the real analysis object

  foreach my $feature (@{$self->output}) {
    if($feature->isa('Bio::EnsEMBL::FeaturePair')) {
      $feature->analysis($self->analysis);
    }
  }

  $self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor->store(@{$self->output});
}


sub output {
  my ($self, @args) = @_;

  throw ("Cannot call output without a runnable") if (!defined($self->runnable));

  return $self->runnable->output(@args);
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
  #my $params = eval($self->analysis->parameters); 
  my $params = eval($self->analysis->data); 
  
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
  my $blastdb     = new Bio::EnsEMBL::Analysis::Runnable::BlastDB (
      -dbfile     => $fastafile,
      -type       => 'PROTEIN');
  $blastdb->run;
  print("registered ". $blastdb->dbname . " for ".$blastdb->dbfile . "\n");

  printf("took %d secs to dump database to local disk\n", (time() - $startTime));

  return $fastafile;
}

1;
