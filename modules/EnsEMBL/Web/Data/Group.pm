package EnsEMBL::Web::Data::Group;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::Trackable;
use EnsEMBL::Web::Data::Membership;
use EnsEMBL::Web::DBSQL::MySQLAdaptor;
use EnsEMBL::Web::DBSQL::SQL::Request;

our @ISA = qw(EnsEMBL::Web::Data::Trackable);

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
  $self->add_has_many({ class => 'EnsEMBL::Web::Data::Bookmark', owner => 'group'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Data::Configuration', owner => 'group'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Data::Annotation', owner => 'group'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Data::DAS', owner => 'group'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Data::Invite', owner => 'group'});
  $self->add_has_many({ class => 'EnsEMBL::Web::Data::User', table => 'user', link_table => 'group_member', contribute => [ 'level', 'member_status' ] });
  $self->populate_with_arguments($args);
}

sub find_user_by_user_id {
  my ($self, $user_id) = @_;
  my ($user) = grep { $_->id eq $user_id } @{ $self->users };
  return $user;
}

sub assign_status_to_user {
  my ($self, $user, $status) = @_;
  ## TODO: Error exception!

  my $membership = EnsEMBL::Web::Data::Membership->new({
    user_id     => $user->id,
    webgroup_id => $self->id,
  });
  
  $membership->member_status($status);
  $membership->save;
}

sub assign_level_to_user {
  my ($self, $user, $level) = @_;
  ## TODO: Error exception!

  my $membership = EnsEMBL::Web::Data::Membership->new({
    user_id     => $user->id,
    webgroup_id => $self->id,
  });
  
  $membership->level($level);
  $membership->save;
}

sub all_groups_by_type {
  my ($self, $type) = @_;
  my $request = EnsEMBL::Web::DBSQL::SQL::Request->new();
  $request->set_action('select');
  $request->set_table('webgroup');
  $request->add_where('type', $type);

  my @groups;
  my $result = $self->get_adaptor->find_many($request);
  foreach my $id (keys %{ $result->get_result_hash }) {
    push @groups, __PACKAGE__->new({ id => $id });
  }
  
  return \@groups;
}

}

1;
