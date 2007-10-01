package EnsEMBL::Web::Object::Data::Bookmark;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data::Trackable;
use EnsEMBL::Web::Object::Data::Owned;

our @ISA = qw(EnsEMBL::Web::Object::Data::Trackable  EnsEMBL::Web::Object::Data::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('bookmark');
  $self->attach_owner($args->{'record_type'});
  $self->add_field({ name => 'url', type => 'text' });
  $self->add_field({ name => 'name', type => 'text' });
  $self->add_field({ name => 'description', type => 'text' });
  $self->add_field({ name => 'click', type => 'int' });
  $self->populate_with_arguments($args);
}

}

1;
