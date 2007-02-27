package EnsEMBL::Web::Object::Data::Group;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  $self->set_primary_key('webgroup_id');
  $self->set_adaptor(EnsEMBL::Web::DBSQL::MySQLAdaptor->new({table => 'webgroup' }));
  $self->set_data_field_name('data');
  $self->add_queriable_field({ name => 'name', type => 'text' });
  $self->add_queriable_field({ name => 'blurb', type => 'text' });
  $self->add_queriable_field({ name => 'type', type => "enum('open','restricted','private')" });
  $self->add_queriable_field({ name => 'status', type => "enum('active','inactive')" });
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Group::Bookmark', table => 'group_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Group::Configuration', table => 'group_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Group::Annotation', table => 'group_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Group::Invite', table => 'group_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::User', table => 'user', link_table => 'group_member', contribute => [ 'level' ] });
  $self->populate_with_arguments($args);
}

}

1;
