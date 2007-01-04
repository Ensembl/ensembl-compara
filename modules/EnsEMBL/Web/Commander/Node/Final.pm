package EnsEMBL::Web::Commander::Node::Final;

use strict;
use warnings;

our @ISA = qw(EnsEMBL::Web::Commander::Node);

{

my %Destination_of;

sub is_final {
  return 1;
}

sub destination {
  ### a
  my $self = shift;
  $Destination_of{$self} = shift if @_;
  return $Destination_of{$self};
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Destination_of{$self};
}

}

1;
