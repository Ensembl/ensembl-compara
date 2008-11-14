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
  
  my $msg1 = 'In the near future this page will display personal annotations '.
             'that you provide for a protein. This feature is currently in '.
             'development.';
  my $msg2 = "Click 'configure this page' to change the sources of external ".
             "annotations that are available in the External Data menu.";
  return $self->_info('Coming soon', $msg1, '100%') .
         $self->_info('Info',        $msg2, '100%');
}

1;

