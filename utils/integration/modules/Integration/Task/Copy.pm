package Integration::Task::Copy;

use strict;
use warnings;

use Integration::Task;
our @ISA = qw(Integration::Task);

{

sub process {
  ### Performs a copy of the file defined by {{source}} file to {{destination}}.
  my $self = shift;
  my $command = "cp -r " . $self->source . " " . $self->destination;
  my $cp = `$command`;
  return 1;
}

}

1;
