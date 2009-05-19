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
  
  my $translation = $self->object->translation_object;
  if ( !$translation ) {
    my $msg = 'This transcript does not have a protein product. External data '.
              'is only supported for proteins.';
    return $self->_error( 'No protein product', $msg, '100%' );
  }
  
  my $msg = "Click 'configure this page' to change the sources of external ".
             "annotations that are available in the External Data menu.";
  return $self->_info('Info',        $msg, '100%');
}

1;

