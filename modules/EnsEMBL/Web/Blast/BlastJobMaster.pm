package EnsEMBL::Web::Object::BlastJobMaster;

use strict;
use warnings;
no warnings 'uninitialized';

use vars qw($PROCESS_LIMIT);

use EnsEMBL::Web::Queue::LSF;
use EnsEMBL::Web::Blast::Parser;

use Benchmark;

BEGIN {
  $PROCESS_LIMIT = 1;
}

sub new {

  ## queue_class should be a class name that inherits from
  ## EnsEMBL::Web::Queue, or that implements the queue_job
  ## and type methods.

  my ($class, $adaptor, $queue_class) = @_;
  my $self = { 
              'blast_adaptor' => undef,
              'queue_class' => undef,
              'queue' => undef
             };
  bless $self, $class;
  $self->blast_adaptor($adaptor);
  $self->queue_class($queue_class);
  $self->queue($queue_class->new);

  warn "Instantiating Queue object: " . $self->queue->type; 

  return $self;
}

sub blast_adaptor {
  my ($self, $adaptor) = @_;
  if ($adaptor) {
    $self->{'blast_adaptor'} = $adaptor;
  }
  return $self->{'blast_adaptor'};
}

sub queue_class {
  my ($self, $value) = @_;
  my $key = "queue_class";
  if ($value) {
    $self->{$key} = $value;
  }
  return $self->{$key};
}

sub queue {
  my ($self, $value) = @_;
  my $key = "queue";
  if ($value) {
    $self->{$key} = $value;
  }
  return $self->{$key};
}

sub queue_pending_jobs {
  my $self = shift;

  ## BlastAdaptor returns arrays of BlastRequest objects when 
  ## responding to pending_jobs.

  my @pending = $self->blast_adaptor->pending_jobs;
  foreach my $job (@pending) {
    $self->queue_job($job);  
  }
}

sub queue_job {
  my ($self, $job) = @_;
  my @running = @{ $self->blast_adaptor->running_jobs };
  if ($#running < $PROCESS_LIMIT) {
    $self->queue->queue_job($job);
    $self->blast_adaptor->set_running_status_for_job($job->id);
  }
}

sub process_completed_jobs {
  my $self = shift;
  my @completed = $self->blast_adaptor->completed_jobs;
  my $start = new Benchmark;
  foreach my $job (@completed) {
    $self->process_completed_job($job);  
  }
  my $end = new Benchmark;
  warn "Job processing complete: " . timestr(timediff($end, $start));

}

sub process_completed_job {
  my ($self, $job) = @_;
  warn("Processing completed job: " . $job->ticket);
  my $parser = EnsEMBL::Web::Blast::Parser->new({ 'job' => $job });
  my @hsps = $parser->parse($job);
  foreach my $hsp (@hsps) {
    $self->blast_adaptor->create_hsp_and_alignments({ 'hsp' => $hsp, 'job' => $job});
  }
#  $self->blast_adaptor->set_parsed_status_for_job($job->id);
}

1; 
