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
  my $msg = $self->config_msg; 
  return $self->_info('Info', $msg, '100%');
  
}

1;
