package Integration::Task::Execute;

use strict;
use warnings;

use Integration::Task;
our @ISA = qw(Integration::Task);

{

sub process {
  ### Runs the command specified in {{source}}. 
  my $self = shift;
  my $command = $self->source;
  my $cp = `$command`;
  return 1;
}

}

1;
