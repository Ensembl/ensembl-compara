package EnsEMBL::Web::Object::Group;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);
use CGI::Cookie;

use EnsEMBL::Web::Record;
use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Record);

{

my %Name_of;
my %Description_of;
my %Type_of;
my %Status_of;
my %CreatedBy_of;
my %ModifiedBy_of;
my %CreatedAt_of;
my %ModifiedAt_of;
my %Users_of;
my %Administrators_of;
my %RemovedUsers_of;
my %AddedUsers_of;
my %StatusCollection_of;
my %LevelCollection_of;

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $Name_of{$self} = defined $params{'name'} ? $params{'name'} : "";
  $Description_of{$self} = defined $params{'description'} ? $params{'description'} : "DESCRIPTION";
  $Type_of{$self} = defined $params{'type'} ? $params{'type'} : "open";
  $Status_of{$self} = defined $params{'status'} ? $params{'status'} : "active";
  $CreatedBy_of{$self} = defined $params{'created_by'} ? $params{'created_by'} : 0;
  $ModifiedBy_of{$self} = defined $params{'modified_by'} ? $params{'modified_by'} : 0;
  $CreatedAt_of{$self} = defined $params{'created_at'} ? $params{'created_at'} : 0;
  $ModifiedAt_of{$self} = defined $params{'modified_at'} ? $params{'modified_at'} : 0;
  $Users_of{$self} = defined $params{'users'} ? $params{'users'} : [];
  $AddedUsers_of{$self} = defined $params{'added'} ? $params{'added'} : [];
  $RemovedUsers_of{$self} = defined $params{'removed'} ? $params{'removed'} : [];
  $StatusCollection_of{$self} = defined $params{'status_collection'} ? $params{'status_collection'} : {};
  $LevelCollection_of{$self} = defined $params{'level_collection'} ? $params{'level_collection'} : {};

  if (!$self->adaptor) {
    $self->adaptor($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor);
  }

  if ($params{id} and !$params{defer}) {
    my $details = $self->adaptor->group_by_id($params{'id'})->[0];
    $self->populate_details($details);
    my @records = $self->find_group_records_by_group_id($params{'id'}, { adaptor => $self->adaptor });
    $self->records(\@records);
    $self->update_users;
  }
  return $self;
}

sub load {
  my $self = shift;
  my @records = $self->find_group_records_by_group_id($self->id, { adaptor => $self->adaptor });
  $self->records(\@records);
}

sub populate_details {
  my ($self, $details) = @_;
  $self->id($details->{id});
  $Name_of{$self} = $details->{name};
  $Type_of{$self} = $details->{type};
  $Status_of{$self} = $details->{status};
  $Description_of{$self} = $details->{blurb};
  $CreatedBy_of{$self} = $details->{created_by};
  $ModifiedBy_of{$self} = $details->{modified_by};
  $CreatedAt_of{$self} = $details->{created_at};
  $ModifiedAt_of{$self} = $details->{modified_at};
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

sub all_groups_by_type {
  my ($self, $type) = @_;

  if (!$self->adaptor) {
    $self->adaptor($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor);
  }

  my $results = $self->adaptor->groups_for_type($type);
  my $groups = [];
  if ($results) {
    foreach my $result (@{ $results }) {
      my $group = EnsEMBL::Web::Object::Group->new();
      $group->populate_details($result);
      $group->update_users;
      push @{ $groups }, $group;
    }
  }
  return $groups;
}

sub update_users {
  my $self = shift;
  my $results = $self->adaptor->find_users_by_group_id($self->id, { adaptor => $self->adaptor });
  if ($results) {
    $self->users([]);
    foreach my $result (@{ $results }) {
      my $user = EnsEMBL::Web::Object::User->new({
                                            adaptor => $self->adaptor,
                                            name => $result->{'name'},          
                                            email => $result->{'email'},
                                            organisation => $result->{'org'},
                                              });
      $user->id($result->{'id'});
      push @{ $self->users }, $user; 

      if ($result->{'level'} eq 'administrator') {
        $self->assign_level_to_user($result->{'level'}, $user);
      }
  
      if ($result->{'status'}) {
        $self->assign_status_to_user($result->{'status'}, $user);
      }

    }
  }
}

sub assign_level_to_user {
  my ($self, $level, $user) = @_;
  if ($self->level_collection->{$level}) {
    push @{ $self->level_collection->{$level} }, $user;
  } else {
    $self->level_collection->{$level} = [ $user ];
  }
}

sub assign_status_to_user {
  my ($self, $status, $user) = @_;
  if ($self->status_collection->{$status}) {
    push @{ $self->status_collection->{$status} }, $user;
  } else {
    $self->status_collection->{$status} = [ $user ];
  }
}

sub find_users_by_status {
  my ($self, $status) = @_;
  if ($self->status_collection->{$status}) {
    return $self->status_collection->{$status};
  }
  return [];
}

sub find_users_by_level {
  my ($self, $level) = @_;
  if ($self->level_collection->{$level}) {
    return $self->level_collection->{$level};
  }
  return [];
}

sub find_level_for_user {
  my ($self, $user) = @_;
  foreach my $this_user (@{ $self->users }) {
    if ($this_user->id eq $user->id) {
      return $user->level;
    }
  }
  return "member";
}

sub save {
  my $self = shift;
  #warn "CHECKING FOR DATA TAINT: " . $self->tainted->{'users'};
  #warn "PERFORMING GROUP SAVE: "  . $self->description;
  my %params = (
                 name        => $self->name,
                 blurb       => $self->description,
                 type        => $self->type,
                 status      => $self->status,
                 created_by  => $self->created_by
               );
  if ($self->id) {
    #warn "UPDATING GROUP: " . $self->id;
    #warn "UPDATING GROUP: " . $self->status;
    $params{id} = $self->id;
    $self->adaptor->update_group(%params, ('modified_by', $self->modified_by) );
  } else {
    #warn "INSERTING NEW GROUP";
    $self->id($self->adaptor->insert_group(%params, 
                                          ('created_by', $self->created_by,
                                           'modified_by', $self->modified_by)
                                          ));
  }
  if ($self->tainted->{'users'}) {
    #warn "MODIFYING RELATIONSHIP";
    if ($self->added_users) {
      foreach my $user (@{ $self->added_users }) {
        #warn "MAPPING " . $user->name;
        my %relationship = (
                           from    => $self->id,
                           to      => $user->id,
                           level   => "member", 
                           status  => 'active'
                         );
        $self->adaptor->add_relationship(%relationship);
      }
      $self->added_users([]);
    }
    if ($self->removed_users) {
      #warn "REMOVING RELATIONSHIP";
      foreach my $user (@{ $self->removed_users }) {
        my %relationship = (
                           from    => $self->id,
                           to      => $user->id,
                         );
        $self->adaptor->remove_relationship(%relationship);
      }
    }
  }
}

sub add_relationship {
  my ($self, %relationship) = @_;
  if (!$self->adaptor) {
    $self->adaptor($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor);
  }
  $self->adaptor->add_relationship(%relationship);
}

sub users {
  ### a
  my $self = shift;
  $Users_of{$self} = shift if @_;
  return $Users_of{$self};
}

sub add_user {
  my ($self, $user) = @_;
  my $level = "member";
  if (!$self->is_user_member($user)) {
    push @{ $Users_of{$self} }, $user;
    $self->assign_level_to_user($level, $user);
    push @{ $AddedUsers_of{$self} }, $user;
    $self->taint('users');
  }
}

sub is_user_member {
  my ($self, $user) = @_;
  my $found = 0;
  foreach my $check_user(@{ $self->users }) {
    if ($user->id == $check_user->id) {
      $found = 1;
    }
  }
  return $found;
}

sub name {
  ### a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub description {
  ### a
  my $self = shift;
  $Description_of{$self} = shift if @_;
  return $Description_of{$self};
}

sub type {
  ### a
  my $self = shift;
  $Type_of{$self} = shift if @_;
  return $Type_of{$self};
}

sub status {
  ### a
  my $self = shift;
  $Status_of{$self} = shift if @_;
  return $Status_of{$self};
}

sub created_by {
  ### a
  my $self = shift;
  $CreatedBy_of{$self} = shift if @_;
  return $CreatedBy_of{$self};
}

sub modified_by {
  ### a
  my $self = shift;
  $ModifiedBy_of{$self} = shift if @_;
  return $ModifiedBy_of{$self};
}

sub created_at {
  ### a
  my $self = shift;
  $CreatedAt_of{$self} = shift if @_;
  return $CreatedAt_of{$self};
}

sub modified_at {
  ### a
  my $self = shift;
  $ModifiedAt_of{$self} = shift if @_;
  return $ModifiedAt_of{$self};
}

sub administrators {
  ### a
  my $self = shift;
  return $self->find_users_by_level('administrator');
}

sub status_collection {
  ### a
  my $self = shift;
  $StatusCollection_of{$self} = shift if @_;
  return $StatusCollection_of{$self};
}

sub level_collection {
  ### a
  my $self = shift;
  $LevelCollection_of{$self} = shift if @_;
  return $LevelCollection_of{$self};
}

sub removed_users {
  ### a
  my $self = shift;
  $RemovedUsers_of{$self} = shift if @_;
  return $RemovedUsers_of{$self};
}

sub added_users {
  ### a
  my $self = shift;
  $AddedUsers_of{$self} = shift if @_;
  return $AddedUsers_of{$self};
}

sub remove_user {
  ### Removes a user from the group
  my ($self, $user) = @_;
  if (!$self->removed_users) {
    $self->removed_users([]);
  }
  #warn "REMOVING REMOVE_USER: " . $user->name;
  push @{ $self->removed_users }, $user; 
  $self->taint('users');
  #warn "TAINT: " . $self->tainted->{'users'};
}

sub DESTROY {
  my $self = shift;
  delete $Name_of{$self};
  delete $Description_of{$self};
  delete $Type_of{$self};
  delete $Status_of{$self};
  delete $CreatedBy_of{$self};
  delete $ModifiedBy_of{$self};
  delete $CreatedAt_of{$self};
  delete $ModifiedAt_of{$self};
  delete $Administrators_of{$self};
  delete $StatusCollection_of{$self};
  delete $LevelCollection_of{$self};
  delete $RemovedUsers_of{$self};
  delete $AddedUsers_of{$self};
}

}

1;
