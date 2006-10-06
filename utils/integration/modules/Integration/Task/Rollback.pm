package Integration::Task::Rollback;

use strict;
use warnings;

use Integration::Task;
our @ISA = qw(Integration::Task);

{

my %Prefix_of;

sub new {
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $Prefix_of{$self} = defined $params{prefix} ? $params{prefix} : "old";
  if ($self->prefix) {
    my @elements = split(/\//, $self->source);
    my $result = "";
    my $count = 0;
    foreach my $element (@elements) {
      if ($count == $#elements) {
        $result .= $self->prefix . $element;
      } else {
        $result .= $element . "/";
      }
      $count++;
    }
    $self->destination($result);
  }
  return $self;
}

sub rollback {
  my $self = shift;
  if (-e $self->source) {
    my $command = "rm -r " . $self->source;
    warn "ROLLBACK: $command";
    my $rm = `$command`;
  }
  my $command = "mv " . $self->destination . " " . $self->source;
  warn "ROLLBACK: $command";
  my $mv = `$command`;
  return 1;
}

sub purge {
  my $self = shift;
  my $command = "rm -r " . $self->destination;
  my $rm = `$command`;
  return 1;
}

sub process {
  ### Sets up the {{source}} for future {{rollbacks}} of {{purging}}.
  my $self = shift;
  my $command = "mv " . $self->source . " " . $self->destination;
  my $mv = `$command`;
  return 1;
}

sub prefix {
  ### a
  my $self = shift;
  $Prefix_of{$self} = shift if @_;
  return $Prefix_of{$self};
}


sub DESTROY {
  my $self = shift;
  delete $Prefix_of{$self}; 
}

}

1;
