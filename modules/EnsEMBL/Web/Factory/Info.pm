package EnsEMBL::Web::Factory::Info;

use strict;

use base qw(EnsEMBL::Web::Factory);
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::RegObj;

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );
  return $self;
}

sub createObjects { 
  my $self        = shift;

  ## Create a very lightweight object, as the home page doesn't need much

  $self->DataObjects( new EnsEMBL::Web::Proxy::Object(
    'Info', {}, $self->__data
  ) ); 
}

1;
