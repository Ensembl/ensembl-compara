package EnsEMBL::Web::Blast;

use strict;
use warnings;
no warnings "uninitialized";

use vars qw($LOCATION);

BEGIN {
  $LOCATION = "/ensemblweb/mw4/wwwdev/blast";
}

sub new {
  my ($class, $parameters) = @_;
  my $self = {
              'filename' => undef,
              'warnings' => undef, 
              'results' => undef, 
              'job' => undef 
             };
  bless $self, $class;
  if ($parameters->{'job'}) {
    $self->job($parameters->{'job'});
  }
  if ($parameters->{'filename'}) {
    $self->filename($parameters->{'filename'});
  }
  return $self;
}

sub job {
  my ($self, $value) = @_;
  $self->params('job', $value);
}

sub filename {
  my ($self, $value) = @_;
  if ($self->job) {
    return $LOCATION . "/" . $self->job->ticket . "/output";
  } else {
    if ($value) {
      $self->{'filename'} = $value;
    }
    return $self->{'filename'};
  }
}

sub params {
  my ($self, $key, $value) = @_;
  if ($value) {
    $self->{$key} = $value;
  }
  return $self->{$key};
}

sub warnings {
  my ($self, @warnings) = @_;
  if (@warnings) {
    $self->{'warnings'} = \@warnings;
  }
  return $self->{'warnings'}; 
}

sub results {
  my ($self, @results) = @_;
  if (@results) {
    $self->{'results'} = \@results;
  }
  return $self->{'results'}; 
}

1;
