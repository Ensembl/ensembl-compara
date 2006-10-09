package Integration::Task::Copy;

use strict;
use warnings;

use Integration::Task;
our @ISA = qw(Integration::Task);

{

sub process {
  ### Creates a new symlink. Symlink is created with {{destination}} pointing to {{source}}. 
  my $self = shift;
  my $command = "ln -s " . $self->source . " " . $self->destination;
  my $cp = `$command`;
  return 1;
}

}

1;
