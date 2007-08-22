package EnsEMBL::Web::Object::Data::Bookmark;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;
use EnsEMBL::Web::Object::Data::Trackable;
use EnsEMBL::Web::Object::Data::Owned;

our @ISA = qw(EnsEMBL::Web::Object::Data::Trackable  EnsEMBL::Web::Object::Data::Owned);


{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->type('bookmark');
  $self->attach_owner($args->{'record_type'});
  $self->set_primary_key($self->key);
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => $self->table }));
  $self->add_field({ name => 'url', type => 'text' });
  $self->add_field({ name => 'name', type => 'text' });
  $self->add_field({ name => 'description', type => 'text' });
  $self->add_field({ name => 'click', type => 'int' });
  $self->populate_with_arguments($args);
}

}

1;
