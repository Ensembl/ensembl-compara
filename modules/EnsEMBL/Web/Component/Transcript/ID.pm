package EnsEMBL::Web::Component::Transcript::ID;

use strict;
use warnings;
no warnings "uninitialized";

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {

return;
}

1;
