#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::Hive::AnalysisJob

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

package Bio::EnsEMBL::Compara::Hive::AnalysisJob;

use strict;

use Bio::EnsEMBL::Root;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Hive::Worker;

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Root);


sub adaptor {
  my $self = shift;
  $self->{'_adaptor'} = shift if(@_);
  return $self->{'_adaptor'};
}

sub dbID {
  my $self = shift;
  $self->{'_dbID'} = shift if(@_);
  return $self->{'_dbID'};
}

sub input_id {
  my( $self, $value ) = @_;
  $self->{'_input_id'} = $value if($value);
  return $self->{'_input_id'};
}

sub hive_id {
  my $self = shift;
  $self->{'_hive_id'} = shift if(@_);
  return $self->{'_hive_id'};
}

sub analysis_id {
  my( $self, $value ) = @_;
  $self->{'_analysis_id'} = $value if($value);
  return $self->{'_analysis_id'};
}

sub job_claim {
  my( $self, $value ) = @_;
  $self->{'_job_claim'} = $value if($value);
  return $self->{'_job_claim'};
}

sub status {
  my( $self, $value ) = @_;

  if($value) {
    $self->{'_status'} = $value;
    $self->adaptor->update_status($self) if($self->adaptor);
  }
  return $self->{'_status'};
}

sub retry_count {
  my( $self, $value ) = @_;
  $self->{'_retry_count'} = $value if($value);
  return $self->{'_retry_count'};
}

sub completed {
  my( $self, $value ) = @_;
  $self->{'_completed'} = $value if($value);
  return $self->{'_completed'};
}

sub result {
  my( $self, $value ) = @_;
  $self->{'_result'} = $value if($value);
  return $self->{'_result'};
}

sub print_job {
  my $self = shift;
  print("WORKER: hive_id=",$self->hive_id,
     " host=",$self->host,
     " ppid=",$self->process_id,
     "\n");  
}

1;