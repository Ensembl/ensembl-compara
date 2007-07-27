package EnsEMBL::Web::Object::Data::SpeciesList;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;
use EnsEMBL::Web::Object::Data::Trackable;
use EnsEMBL::Web::Object::Data::Record;

our @ISA = qw(EnsEMBL::Web::Object::Data::Trackable  EnsEMBL::Web::Object::Data::Record);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('specieslist');
  $self->attach_owner('user');
  $self->set_primary_key($self->key);
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => $self->table }));
  $self->add_field({ name => 'favourites', type => 'text' });
  $self->add_field({ name => 'list', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
