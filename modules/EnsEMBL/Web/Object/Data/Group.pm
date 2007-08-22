package EnsEMBL::Web::Object::Data::Group;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Object::Data::Trackable;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data::Trackable);

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
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Bookmark', owner => 'group'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Configuration', owner => 'group'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Annotation', owner => 'group'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::DAS', owner => 'group'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Invite', owner => 'group'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::User', table => 'user', link_table => 'group_member', contribute => [ 'level', 'status' ] });
  $self->populate_with_arguments($args);
}

sub find_user_by_user_id {
  my ($self, $user_id) = @_;
  foreach my $user (@{ $self->users }) {
    if ($user->id eq $user_id) {
      return $user;
    }
  }
  return 0;
}


}

1;
