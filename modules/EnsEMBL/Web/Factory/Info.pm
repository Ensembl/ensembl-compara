package EnsEMBL::Web::Factory::Info;

use strict;

use base qw(EnsEMBL::Web::Factory);

sub new {
  my $class = shift;
  my $self = $class->SUPER::new( @_ );
  return $self;
}

sub createObjects { 
  my $self        = shift;

  ## Create a very lightweight object, as the home page doesn't need much

  $self->DataObjects($self->new_object(
    'Info', {}, $self->__data
  ) ); 
}

1;
