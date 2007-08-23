package EnsEMBL::Web::Object::Data::User;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Object::Data::Trackable;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;

our @ISA = qw(EnsEMBL::Web::Object::Data::Trackable);

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

  $self->add_relational_field({ name => 'level', type => 'text' });
  $self->add_relational_field({ name => 'member_status', type => 'text' });

  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Bookmark', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Configuration', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Annotation', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::DAS', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::News', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Infobox', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Opentab', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Sortable', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Mixer', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::CurrentConfig', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::SpeciesList', owner => 'user'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Object::Data::Group', table => 'webgroup', link_table => 'group_member', });

  $self->populate_with_arguments($args);
}

sub find_administratable_groups {
  my $self = shift;
  my @admin = ();
  foreach my $group (@{ $self->groups }) {
    foreach my $user (@{ $group->users }) {
      if ($user->id eq $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user->id) {
        if ($user->level eq 'administrator' || $user->level eq 'superuser') {
          push @admin, $group;
        }
      }
    }
  }
  return \@admin;
}

sub is_administrator_of {
  my ($self, $group) = @_; 
  my @admins = @{ $self->find_administratable_groups };
  my $found = 0;
  foreach my $admin_group (@admins) {
    if ($admin_group->id eq $group->id) {
      $found = 1;
    }
  }
  return $found;
}

sub is_member_of {
  my ($self, $group) = @_; 
  my $found = 0;
  foreach my $gp (@{ $self->groups }) {
    if ($gp->id eq $group->id) {
      $found = 1;
      next;
    }
  }
  return $found;
}

}

1;
