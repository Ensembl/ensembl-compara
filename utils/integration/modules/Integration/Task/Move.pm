package Integration::Task::Move;

use strict;
use warnings;

use Integration::Task;
our @ISA = qw(Integration::Task);

{

sub process {
  ### Performs a move of the file or directory defined by {{source}}
  ### to {{destination}}.
  my $self = shift;
  my $command = "mv " . $self->source . " " . $self->destination;
  my $cp = `$command`;
  return 1;
}

}

1;
