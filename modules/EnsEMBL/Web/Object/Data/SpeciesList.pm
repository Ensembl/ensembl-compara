package EnsEMBL::Web::Object::Data::SpeciesList;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data::Trackable;
use EnsEMBL::Web::Object::Data::Owned;

our @ISA = qw(EnsEMBL::Web::Object::Data::Trackable  EnsEMBL::Web::Object::Data::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('specieslist');
  $self->attach_owner('user');
  $self->add_field({ name => 'favourites', type => 'text' });
  $self->add_field({ name => 'list', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
