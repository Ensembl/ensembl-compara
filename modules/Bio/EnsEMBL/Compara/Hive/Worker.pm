#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Hive::Worker

=cut

=head1 SYNOPSIS

Object which encapsulates the details of how to find jobs, how to run those
jobs, and then checked the rules to create the next jobs in the chain.
Essentially knows where to find data, how to process data, and where to
put it when it's done (put in next person's INBOX) so the next Worker
in the chain can find data to work on.

Hive based processing is a concept based on a more controlled version
of an autonomous agent type system.  Each worker is not told what to do
(like a centralized control system - like the current pipeline system)
but rather queries a central database for jobs (give me jobs).

Each worker is linked to an analysis_id, registers its self on creation
into the Hive, creates a RunnableDB instance of the Analysis->module,
gets $runnable->batch_size() jobs from the analysis_job table, does its
work, creates the next layer of analysis_job entries by querying simple_rule
table where condition_analysis_id = $self->analysis_id.  It repeats
this cycle until it's lived it's lifetime or until there are no more jobs left.
The lifetime limit is just a safety limit to prevent these from 'infecting'
a system.

The Queens job is to simply birth Workers of the correct analysis_id to get the
work down.  The only other thing the Queen does is free up jobs that were
claimed by Workers that died unexpectantly so that other workers can take
over the work.

=cut

=head1 DESCRIPTION

=cut

=head1 CONTACT

Jessica Severin, jessica@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Hive::Worker;

use strict;

use Bio::EnsEMBL::Root;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::RunnableDB;
use Bio::EnsEMBL::Compara::Hive::AnalysisJobAdaptor;
use Bio::EnsEMBL::Compara::Hive::Extensions;

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Root);


sub init {
  my $self = shift;
  return $self;
}

sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}
sub db {
  my $self = shift;
  $self->{'_db'} = shift if(@_);
  return $self->{'_db'};
}

=head2 analysis
  Arg [1] : (optional) Bio::EnsEMBL::Analysis $value
  Title   :   analysis
  Usage   :   $value = $self->analysis;
              $self->analysis($$analysis);
  Description: Get/Set analysis object of this Worker
  DefaultValue : undef
  Returntype : Bio::EnsEMBL::Analysis object
=cut

sub analysis {
  my $self = shift;
  my $analysis = shift;

  if(defined($analysis)) {
    $self->throw("analysis arg must be a [Bio::EnsEMBL::Analysis] not a [$analysis]")
       unless($analysis->isa('Bio::EnsEMBL::Analysis'));
    $self->{'_analysis'} = $analysis;
  }

  return $self->{'_analysis'};
}


=head2 life_span
  Arg [1] : (optional) integer $value (in seconds)
  Title   :   life_span
  Usage   :   $value = $self->life_span;
              $self->life_span($new_value);
  Description: Defines the maximum time a worker can live for. Workers are always
               allowed to complete the jobs they get, but whether they can
               do multiple rounds of work is limited by their life_span
  DefaultValue : 1200 (20 minutes)
  Returntype : integer scalar
=cut

sub life_span {
  my( $self, $value ) = @_;
  $self->{'_life_span'} = 20*60 unless($self->{'_life_span'});
  $self->{'_life_span'} = $value if($value);
  return $self->{'_life_span'};
}

sub hive_id {
  my( $self, $value ) = @_;
  $self->{'_hive_id'} = $value if($value);
  return $self->{'_hive_id'};
}

sub host {
  my( $self, $value ) = @_;
  $self->{'_host'} = $value if($value);
  return $self->{'_host'};
}

sub process_id {
  my( $self, $value ) = @_;
  $self->{'_ppid'} = $value if($value);
  return $self->{'_ppid'};
}

sub work_done {
  my( $self, $value ) = @_;
  $self->{'_work_done'} = 0 unless($self->{'_work_done'});
  $self->{'_work_done'} = $value if($value);
  return $self->{'_work_done'};
}

sub cause_of_death {
  my( $self, $value ) = @_;
  $self->{'_cause_of_death'} = $value if($value);
  return $self->{'_cause_of_death'};
}

sub born {
  my( $self, $value ) = @_;
  $self->{'_born'} = $value if($value);
  return $self->{'_born'};
}

sub died {
  my( $self, $value ) = @_;
  $self->{'_died'} = $value if($value);
  return $self->{'_died'};
}

sub last_check_in {
  my( $self, $value ) = @_;
  $self->{'_last_check_in'} = $value if($value);
  return $self->{'_last_check_in'};
}

sub print_worker {
  my $self = shift;
  print("WORKER: hive_id=",$self->hive_id,
     " analysis_id=(",$self->analysis->dbID,")",$self->analysis->logic_name,
     " host=",$self->host,
     " ppid=",$self->process_id,
     "\n");  
}

###############################
#
# WORK section
#
###############################
sub batch_size {
  my $self = shift;
  my $runObj = $self->analysis->runnableDB;
  return $runObj->batch_size if($runObj);
  return 1;
}

sub run
{
  my $self = shift;

  my $alive=1;  
  while($alive) {
    my $jobDBA = $self->db->get_AnalysisJobAdaptor;
    my $claim = $jobDBA->claim_jobs_for_worker($self);
    my $jobs = $jobDBA->fetch_by_job_claim($claim);

    $self->cause_of_death('NO_WORK') unless(scalar @{$jobs});

    print("processing ",scalar(@{$jobs}), "jobs \n");
    foreach my $job (@{$jobs}) {
      $self->run_module_with_job($job);
      $self->create_next_jobs($job);
      $job->status('DONE');
      $self->{'_work_done'}++;
    }
    $alive=undef if($self->cause_of_death);
  }

  $self->cause_of_death('NATURAL') if($self->{'_work_done'}>1000);

  $self->adaptor->register_worker_death($self);
}


sub run_module_with_job
{
  my $self = shift;
  my $job  = shift;

  my $runObj = $self->analysis->runnableDB;
  return 0 unless($runObj);
  return 0 unless($job and ($job->hive_id eq $self->hive_id));

  #pass the input_id from the job into the runnableDB object
  $runObj->input_id($job->input_id);
  
  $job->status('GET_INPUT');
  $runObj->fetch_input;

  $job->status('RUN');
  $runObj->run;

  $job->status('WRITE_OUTPUT');
  $runObj->write_output;

  #runnableDB is allowed to alter it's input_id on output
  #This modified input_id is passed as input to the next jobs in the graph
  $job->input_id($runObj->input_id);

  return 1;
}


sub create_next_jobs
{
  my $self = shift;
  my $job  = shift;

  return unless($self->db);
  my $jobDBA = $self->db->get_AnalysisJobAdaptor;
  
  my $sql = "SELECT goal_analysis_id " .
            "FROM simple_rule " .
            "WHERE condition_analysis_id=".$self->analysis->dbID;
  my $sth = $self->db->prepare( $sql );
  $sth->execute();
  my $goal_analysis_id;
  $sth->bind_columns( \$goal_analysis_id );
  while( $sth->fetch() ) {
    $jobDBA->create_new_job (
        -input_id       => $job->input_id,
        -analysis_id    => $goal_analysis_id,
        -input_job_id   => $job->dbID,
    );
  }
  $sth->finish();
}

1;
