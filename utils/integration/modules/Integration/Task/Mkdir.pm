package Integration::Task::Mkdir;

use strict;
use warnings;

use Integration::Task;
our @ISA = qw(Integration::Task);

{

sub process {
  ### Makes the directory specified by {{source}}. 
  my $self = shift;
  my $command = "mkdir " . $self->source; 
  my $cp = `$command`;
  return 1;
}

}

1;
