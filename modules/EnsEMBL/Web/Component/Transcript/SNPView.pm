package EnsEMBL::Web::Component::Transcript::SNPView;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}


sub content {
  my $self = shift;
  my $object = shift;

 return;
}

1;
