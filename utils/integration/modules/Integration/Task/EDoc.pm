package Integration::Task::EDoc;

use strict;
use warnings;

use Integration::Task;
our @ISA = qw(Integration::Task);

{

sub process {
  ### Builds an e! doc index using the update script at the location specified by {{source}}, and copies it to {{destination}}.
  my $self = shift;
  my $build_command = "perl " . $self->source . "/update_docs.pl";
  my $build = `$build_command`;
  my $command = "cp -r " . $self->source . "/temp " . $self->destination;
  my $cp = `$command`;
  return 1;
}

}

1;
