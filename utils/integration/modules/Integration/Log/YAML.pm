package Integration::Log::YAML;

use strict;
use warnings;

use Integration::Log;
use YAML qw(LoadFile DumpFile);
our @ISA = qw(Integration::Log);

{

my %Location_of;

sub new {
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $Location_of{$self} = defined $params{location} ? $params{location} : "";
  if ($self->location) {
    $self->load;
  }
  return $self;
}

sub load {
  my $self = shift;
  if (-e $self->location) {
    my @array = LoadFile($self->location);
    $self->log(\@array);
  } else {
    my @array = ();
    $self->log(\@array);
  } 
}

sub new_build_number {
  my $self = shift;
  my $build = 0;
  foreach my $event (@{ $self->log }) {
    if ($event->{build}) {
      if ($event->{build} > $build) {
        $build = $event->{build};
      }
    }
  }
  return ($build + 1);
}

sub save {
  my $self = shift;
  DumpFile($self->location, @{ $self->log }); 
}

sub add_event {
  my ($self, $event) = @_;
  if (!$event->{build}) {
    my $new_build = $self->new_build_number;
    $event->{build} = $new_build;
  }
  push @{ $self->log }, $event;
}

sub latest_ok_event {
  my $self = shift;
  my @events = @{ $self->events_with_status('ok') };
  my $latest = 0;
  my $recent = undef; 
  foreach my $event (@events) {
    if ($event->{build} > $latest) {
      $latest = $event->{build};
      $recent = $event;
    }
  }
  return $recent;
}

sub latest_event {
  my $self = shift;
  my @events = @{ $self->log };
  return $events[$#events];
}

sub latest_ok_build_number {
  my $self = shift;
  return $self->latest_ok_event->{build};
}

sub events_with_status {
  my ($self, $status) = @_;
  my @events = ();
  foreach my $event (@{ $self->log }) {
    if ($event->{status} eq $status) {
      push @events, $event;
    }
  }
  return \@events;
}

sub location {
  ### a
  my $self = shift;
  $Location_of{$self} = shift if @_;
  return $Location_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $Location_of{$self};
}

}

1;
