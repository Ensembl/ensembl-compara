package EnsEMBL::Web::Object::BlastTicket;

use strict;
use warnings;
no warnings "uninitialized";

## This class deals with tickets and queue status.
## The Blast request itself (sequence, species, etc) is
## represented by the BlastRequest Object.

## The requests are submitted to the queue (or executed locally)
## by an instance of the BlastJobMaster class.

## All SQL is abstracted into the BlastAdaptor.

sub new {
  my ($class, $properties) = @_;
  my $self = {
	      'id' => undef,
	      'blast_adaptor' => undef,
	      'queue_length' => undef,
	      'running_jobs' => undef,
	      'wait_time' => undef,
	      'ticket' => undef,
             };
  bless $self, $class;
  $self->blast_adaptor($properties->{'blast_adaptor'});
  $self->ticket($properties->{'ticket'});
  return $self;
}

sub create_ticket_with_request {
  my ($self, $request) = @_;
  my $job_id = $self->create_ticket;
  $self->blast_adaptor->create_sequence({
			   'sequence' => $request->sequence,
			   'species' => $request->species,
                           'job_id'   => $job_id
                           });
}

sub create_ticket {
  my $self = shift;
  my $ticket = $self->generate_ticket_id;
  my $job_id = $self->blast_adaptor->create_ticket({
				'ticket' => $ticket, 
				});
  $self->id($ticket);
  return $job_id;
}

sub queue_length {
  my $self = shift;
  if (!$self->{'queue_length'}) {
    my @results = @{ $self->blast_adaptor->queue_length };
    $self->{'queue_length'} = $#results + 1;
  }
  return $self->{'queue_length'}; 
}

sub running_jobs {
  my $self = shift;
  if (!$self->{'running_jobs'}) {
    my @results = @{ $self->blast_adaptor->running_jobs };
    $self->{'running_jobs'} = $#results + 1;
  }
  return $self->{'running_jobs'}; 
}

sub position_in_queue {
  my $self = shift;
  my @pending = $self->blast_adaptor->pending_jobs;
  my $count = 0;
  foreach my $job (@pending) {
    $count++;
    warn $job->ticket;
    if ($job->ticket eq $self->ticket) {
      return $count;
    }
  }
  return -1;
}

sub wait_time {
  my $self = shift;
  my $result = 1900;
  if (!$self->{'wait_time'}) {
    $result = $self->blast_adaptor->wait_time;
  }
  my $remaining = "";
  if ($result < 60) {
    $remaining = "less than a minute";
  } elsif ($result >= 3600) {
    $remaining = sprintf("about %.0f hours", ($result / 60 / 60)) 
  } else {
    $remaining = sprintf("about %.0f minutes", ($result / 60)) 
  }
  return $remaining; 
}

sub generate_ticket_id {
  my $self = shift;
  my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = gmtime(time);
  my $id = $self->blast_adaptor->last_inserted_id . "$sec$min$hour$mday";
  return Digest::MD5->new->add($id)->hexdigest();
}

sub blast_adaptor {
  my ($self, $adaptor) = @_;
  if ($adaptor) { 
    $self->{'blast_adaptor'} = $adaptor;
  }
  return $self->{'blast_adaptor'}; 
} 

sub id {
  my ($self, $id) = @_;
  if ($id) {
    $self->{'id'} = $id;
  } 
  return $self->{'id'};
}

sub ticket {
  my ($self, $value) = @_;
  my $key = 'ticket';
  if ($value) {
    $self->{$key} = $value;
  } 
  return $self->{$key};
}

1;
