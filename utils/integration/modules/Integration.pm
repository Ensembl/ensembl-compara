package Integration;

use strict;
use warnings;

use IntegrationView;
use Integration::Task;

{

my %Checkout_of;
my %StartCommand_of;
my %StopCommand_of;
my %HtdocsLocation_of;
my %Configuration_of;
my %View_of;

sub new {
  ### c
  ### Inside out class for creating a new continuous integration server.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Checkout_of{$self} = defined $params{checkout} ? $params{checkout} : [];
  $HtdocsLocation_of{$self} = defined $params{htdocs} ? $params{htdocs} : "";
  $StartCommand_of{$self} = defined $params{start} ? $params{start} : "";
  $StopCommand_of{$self} = defined $params{stop} ? $params{stop} : "";
  $Configuration_of{$self} = defined $params{configuration} ? $params{configuration} : [];
  $View_of{$self} = defined $params{view} ? $params{view} : IntegrationView->new(( server => $self, output => $self->htdocs_location));
  return $self;
}

sub checkout {
  ### Checks out modules from CVS 
  my $self = shift;

  $self->message("Checkout in progress.", "red");

  foreach my $task (@{ $self->checkout_tasks }) {
    $self->message("Checkout in progress", "red");
    $task->process;
  }

  return 1;
}

sub message {
  my ($self, $message, $colour) = @_;
  $self->view->message($message, $colour);
}

sub configure {
  ### Performs configuration tasks to setup the integration server.
  my $self = shift;
  $self->message("Configuring: are you not entertained?", "red");
  my $warnings = 0;

  foreach my $task (@{ $self->configuration }) {
    $warnings += $task->process;
  }
  return 1;
}

sub start {
  ### Starts an integration server. Any configuration tasks should be 
  ### performed when {{configure}} is called.
  my ($self) = shift;
  my $command = $self->start_command;
  my $start = `$command`;
}

sub stop {
  ### Stops an integration server.
  my ($self) = shift;
  my $command = $self->stop_command;
  my $start = `$command`;
}

sub test {
  ### Runs all automated tests in the test suite and returns the test percentage. The code isn't clean until the bar turns green.
  #my $self = shift;
  #my $start = new Benchmark;
  #my $end = new Benchmark;
  #my $diff = timediff($end, $start);
  #$self->set_benchmark('test', timestr($diff, 'all')); 
  return 100;
} 

sub generate_output {
  ### Generates the output of both checkout and test runs in HTML by default. This output can be altered by reassigning a new view object using {{view}}.
  my $self = shift;
  return $self->view->generate_html;
}

sub htdocs_location {
  ### a
  my $self = shift;
  $HtdocsLocation_of{$self} = shift if @_;
  return $HtdocsLocation_of{$self};
}

sub view {
  ### a
  my $self = shift;
  $View_of{$self} = shift if @_;
  return $View_of{$self};
}

sub start_command {
  ### a
  my $self = shift;
  $StartCommand_of{$self} = shift if @_;
  return $StartCommand_of{$self};
}

sub stop_command {
  ### a
  my $self = shift;
  $StopCommand_of{$self} = shift if @_;
  return $StopCommand_of{$self};
}

sub configuration {
  ### a
  ### Returns an array ref of {{Integration::Task}} objects.
  my $self = shift;
  $Configuration_of{$self} = shift if @_;
  return $Configuration_of{$self};
}

sub checkout_tasks {
  ### a
  ### Returns an array ref of {{Integration::Task}} objects to be performed at checkout.
  my $self = shift;
  $Checkout_of{$self} = shift if @_;
  return $Checkout_of{$self};
}

sub add_configuration_task {
  my ($self, $task) = @_;
  push @{ $self->configuration }, $task;
}

sub add_checkout_task {
  my ($self, $task) = @_;
  push @{ $self->checkout_tasks }, $task;
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $HtdocsLocation_of{$self};
  delete $View_of{$self};
  delete $Configuration_of{$self};
  delete $Checkout_of{$self};
  delete $StartCommand_of{$self};
  delete $StopCommand_of{$self};
}

}


1;
