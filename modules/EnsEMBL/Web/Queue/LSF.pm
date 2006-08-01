package EnsEMBL::Web::Queue::LSF;

use strict;
use warnings;
no warnings 'uninitialized';

use EnsEMBL::Web::Queue;
use EnsEMBL::Web::Object::BlastRequest;

our @ISA = qw(EnsEMBL::Web::Queue);

use vars qw($LOCATION);

BEGIN {
  $LOCATION = "/ensemblweb/mw4/wwwdev/blast";
}

sub queue_job {
  my ($self, $job) = @_;
  $self->job($job);
  warn("Queueing " . $job->ticket . " (" . $job->id . ")"); 
  $self->location($LOCATION);
  $self->create_directory;
  $self->write_sequence;
  $self->write_submission_script;
  $self->submit_job_to_queue;
}

sub write_submission_script {
  my $self = shift; 
  open (OUTPUT, ">" . $self->output_location('submit.sh'));
  print OUTPUT "\n";
  close OUTPUT;
}

sub submit_job_to_queue {
  my $self = shift;
}

sub type {
  return "LSF";
}

1;
