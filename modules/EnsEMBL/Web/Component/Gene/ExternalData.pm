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
  my $self = shift;
  my $msg = "Click 'configure this page' to change the sources of external ".
             "annotations that are available in the External Data menu.";
  return $self->_info('Info', $msg, '100%');
  
}

1;
