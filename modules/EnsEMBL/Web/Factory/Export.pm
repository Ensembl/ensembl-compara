package EnsEMBL::Web::Factory::Export;

use strict;

use base 'EnsEMBL::Web::Factory';

use EnsEMBL::Web::Proxy::Object;

sub createObjects { 
  my $self = shift;
  
  $self->DataObjects(new EnsEMBL::Web::Proxy::Object('Export', undef, $self->__data));
}

1;
