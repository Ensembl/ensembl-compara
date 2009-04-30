package EnsEMBL::Web::Data::Group;

use strict;
use warnings;
use base qw(EnsEMBL::Web::Data::Trackable);
use EnsEMBL::Web::DBSQL::UserDBConnection (__PACKAGE__->species_defs);
use EnsEMBL::Web::Data::User;


__PACKAGE__->table('webgroup');
__PACKAGE__->set_primary_key('webgroup_id');

__PACKAGE__->add_queriable_fields(
  name   => 'text',
  blurb  => 'text',
  type   => "enum('open','restricted','private')",
  status => "enum('active','inactive')",
);

__PACKAGE__->add_has_many(
  records        => 'EnsEMBL::Web::Data::Record',
  bookmarks      => 'EnsEMBL::Web::Data::Record::Bookmark',
  configurations => 'EnsEMBL::Web::Data::Record::Configuration',
  annotations    => 'EnsEMBL::Web::Data::Record::Annotation',
  dases          => 'EnsEMBL::Web::Data::Record::DAS',
  invites        => 'EnsEMBL::Web::Data::Record::Invite',
  uploads        => 'EnsEMBL::Web::Data::Record::Upload',
  urls           => 'EnsEMBL::Web::Data::Record::URL',
);

__PACKAGE__->has_many(members => 'EnsEMBL::Web::Data::Membership');


sub find_user_by_user_id {
  my ($self, $user_id) = @_;
  my ($user) = $self->members(user_id => $user_id);
  return $user;
}

sub assign_status_to_user {
  my ($self, $user_id, $status) = @_;
  ## TODO: Error exception!
  if (my $user = $self->find_user_by_user_id($user_id)) {
    $user->member_status($status);
    $user->save;
  }
}

sub assign_level_to_user {
  my ($self, $user_id, $level) = @_;
  ## TODO: Error exception!
  if (my $user = $self->find_user_by_user_id($user_id)) {
    $user->level($level);
    $user->save;
  }
}

sub add_user {
  my ($self, $user, $level) = @_;
  $level = 'member' unless $level;

  return $self->add_to_members({
    user_id       => $user->id,
    level         => $level,
    member_status => 'active',
  });
}


sub count_records {
  my $self = shift;
  my $count = 0;
  foreach my $accessor (keys %{$self->hasmany_relations}) {
    $count += $self->$accessor;
  }
  return $count;
}

###################################################################################################
##
## Cache related stuff
##
###################################################################################################

sub invalidate_cache {
  my $self  = shift;
  my $cache = shift;

  $self->SUPER::invalidate_cache($cache, 'group['.$self->id.']');
}

sub propagate_cache_tags {
  my $self = shift;
  $self->SUPER::propagate_cache_tags('group['.$self->id.']')
    if ref $self;
}

1;
