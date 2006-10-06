package Integration::Task::Delete;

use strict;
use warnings;

use Integration::Task;
our @ISA = qw(Integration::Task);

{

sub process {
  ### Removes the directory specified by {{source}}. 
  my $self = shift;
  my $command = "rm -r " . $self->source; 
  my $cp = `$command`;
  return 1;
}

}

1;
