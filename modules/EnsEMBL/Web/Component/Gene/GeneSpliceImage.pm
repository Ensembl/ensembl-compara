package EnsEMBL::Web::Component::Gene::GeneSpliceImage;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Gene::GeneSNPImage);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  return undef;
}

sub content {
  return $_[0]->_content(1);
}

1;

