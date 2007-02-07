package EnsEMBL::Web::Object::Data::User;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_primary_key('user_id');
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => 'user' }));
  $self->set_data_field_name('data');
  $self->add_queriable_field({ name => 'name', type => 'text' });
  $self->add_queriable_field({ name => 'email', type => 'text' });
  $self->add_queriable_field({ name => 'salt', type => 'text' });
  $self->add_queriable_field({ name => 'password', type => 'text' });
  $self->add_queriable_field({ name => 'organisation', type => 'text' });
  $self->add_queriable_field({ name => 'status', type => 'text' });
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Bookmark', table => 'user_record'});
  $self->populate_with_arguments($args);
}

}

1;
