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
  $self->add_queriable_field({ name => 'name', type => 'tinytext' });
  $self->add_queriable_field({ name => 'email', type => 'tinytext' });
  $self->add_queriable_field({ name => 'salt', type => 'tinytext' });
  $self->add_queriable_field({ name => 'password', type => 'tinytext' });
  $self->add_queriable_field({ name => 'organisation', type => 'text' });
  $self->add_queriable_field({ name => 'status', type => 'tinytext' });
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::User::Bookmark', table => 'user_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::User::Configuration', table => 'user_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::User::Annotation', table => 'user_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::News', table => 'user_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Infobox', table => 'user_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Opentab', table => 'user_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Sortable', table => 'user_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Mixer', table => 'user_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::SpeciesList', table => 'user_record'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Group', table => 'webgroup', link_table => 'group_member'});

  $self->populate_with_arguments($args);
}

sub find_administratable_groups {
  return [];
}

sub is_administrator_of {
  return 1;
}

}

1;
