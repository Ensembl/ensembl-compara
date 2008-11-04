package EnsEMBL::Web::Component::Transcript::ExternalData;

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
  my $transcript = $self->object;
  my $object     = $transcript->translation_object;
  return $self->_error( 'No protein product', '<p>This transcript does not have a protein product. External data is only supported for proteins.</p>' ) unless $object;
  return "<p>This is the page that will be configured to turn DAS sources on/off</p>";
}

1;

