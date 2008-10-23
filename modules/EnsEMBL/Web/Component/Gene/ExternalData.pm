package EnsEMBL::Web::Component::Gene::ExternalData;

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  return "<p>This is the page that will be configured to turn DAS sources on/off</p>";
}

1;