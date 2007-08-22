package EnsEMBL::Web::Object::Data::Annotation;

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
  $self->type('annotation');
  $self->attach_owner($args->{'record_type'});
  $self->set_primary_key($self->key);
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => $self->table }));
  $self->add_field({ name => 'stable_id', type => 'text' });
  $self->add_field({ name => 'title', type => 'text' });
  $self->add_field({ name => 'url', type => 'text' });
  $self->add_field({ name => 'annotation', type => 'text' });
  $self->populate_with_arguments($args);
}

}

1;
