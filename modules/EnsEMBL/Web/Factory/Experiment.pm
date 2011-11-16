package EnsEMBL::Web::Factory::Experiment; 

## Factory for creating EnsEMBL::Web::Object::Experiment object

use strict;
use warnings;

use base qw(EnsEMBL::Web::Factory);

sub createObjects {
  my $self = shift;

  $self->species_defs->databases->{'DATABASE_FUNCGEN'} or return $self->problem('fatal', 'Database Error', 'There is no functional genomics database for this species.');

  $self->DataObjects($self->new_object('Experiment', {}, $self->__data));
}

1;