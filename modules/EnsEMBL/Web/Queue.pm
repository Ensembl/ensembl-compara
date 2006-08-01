package EnsEMBL::Web::Queue;

use strict;
use warnings;
no warnings 'uninitialized';

sub new {
  my $class = shift;
  my $self = { 
 	       'type' => undef,
	       'job'  => undef 
	     };
  bless $self, $class;
  return $self;
}

sub job {
  my ($self, $value) = @_;
  my $key = "job";
  if ($value) {
    $self->{$key} = $value;
  }
  return $self->{$key};
}

sub write_sequence {
  my $self = shift;
  open (OUTPUT, ">" . $self->output_location('sequence'));
  print OUTPUT $self->job->sequence;
  close OUTPUT;
}

sub create_directory {
  my $self = shift;
  my $directory = $self->output_directory;
  my $mk = `mkdir $directory`;
}

sub output_directory {
  my $self = shift;
  return $self->location . "/" . $self->job->ticket;
}

sub output_location {
  my ($self, $file) = @_;
  return $self->output_directory . "/" . $file;
}

sub location {
  my ($self, $value) = @_;
  my $key = "location";
  if ($value) {
    $self->{$key} = $value;
  }
  return $self->{$key};
}


1;
