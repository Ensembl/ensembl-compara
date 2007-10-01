package EnsEMBL::Web::Object::Data::Configuration;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data::Trackable;
use EnsEMBL::Web::Object::Data::Owned;

our @ISA = qw(EnsEMBL::Web::Object::Data::Trackable  EnsEMBL::Web::Object::Data::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('configuration');
  $self->attach_owner($args->{'record_type'});
  $self->add_field({ name => 'scriptconfig', type => 'text' });
  $self->add_field({ name => 'url', type => 'text' });
  $self->add_field({ name => 'name', type => 'text' });
  $self->add_field({ name => 'description', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
