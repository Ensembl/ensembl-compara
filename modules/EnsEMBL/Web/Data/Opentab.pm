package EnsEMBL::Web::Data::Opentab;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::Trackable;
use EnsEMBL::Web::Data::Owned;

our @ISA = qw(EnsEMBL::Web::Data::Trackable  EnsEMBL::Web::Data::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('opentab');
  $self->attach_owner('user');
  $self->add_field({ name => 'name', type => 'text' });
  $self->add_field({ name => 'tab', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
