package EnsEMBL::Web::Object::Data::Invite;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data::Trackable;
use EnsEMBL::Web::Object::Data::Owned;

our @ISA = qw(EnsEMBL::Web::Object::Data::Trackable  EnsEMBL::Web::Object::Data::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('invite');
  $self->attach_owner('group');
  $self->add_field({ name => 'email', type => 'text' });
  $self->add_field({ name => 'status', type => 'text' });
  $self->add_field({ name => 'code', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
