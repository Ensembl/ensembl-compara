package EnsEMBL::Web::Object::Group;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);
use CGI::Cookie;

use EnsEMBL::Web::Record;
use EnsEMBL::Web::Object::User;

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

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $Name_of{$self} = defined $params{'name'} ? $params{'name'} : "";
  $Description_of{$self} = defined $params{'description'} ? $params{'description'} : "";
  $Type_of{$self} = defined $params{'type'} ? $params{'type'} : "open";
  $Status_of{$self} = defined $params{'status'} ? $params{'status'} : "active";
  $CreatedBy_of{$self} = defined $params{'created_by'} ? $params{'created_by'} : 0;
  $ModifiedBy_of{$self} = defined $params{'modified_by'} ? $params{'modified_by'} : 0;
  $CreatedAt_of{$self} = defined $params{'created_at'} ? $params{'created_at'} : 0;
  $ModifiedAt_of{$self} = defined $params{'modified_at'} ? $params{'modified_at'} : 0;
  $Users_of{$self} = defined $params{'users'} ? $params{'users'} : [];
  $Administrators_of{$self} = defined $params{'administrators'} ? $params{'administrators'} : [];
  if ($params{id}) {
    $self->update_users;
  }
  return $self;
}

sub find_users_by_level {
  my ($self, $level) = @_;
  my $result = [];
  warn "FINDING USERS BY LEVEL $level";
  foreach my $user (@{ $self->users }) {
    warn "CHECKING USER " . $user->name;
    if ($user->level($self) eq $level) {
      push @{ $result }, $user;
    }
  }
  return $result;
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

sub update_users {
  my $self = shift;

  my $results = $self->adaptor->find_users_by_group_id($self->id);
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
        push @{ $self->administrators }, $user;
      }

    }
  }
}

sub save {
  my $self = shift;
  warn "PERFORMING GROUP SAVE:";
  my %params = (
                 name        => $self->name,
                 description => $self->description,
                 type        => $self->type,
                 status      => $self->status
               );
  if ($self->id) {
    warn "UPDATING GROUP: " . $self->id;
    $params{id} = $self->id;
    $self->adaptor->update_group(%params, ('modified_by', $self->modified_by) );
  } else {
    warn "INSERTING NEW GROUP";
    $self->id($self->adaptor->insert_group(%params, 
                                          ('created_by', $self->created_by,
                                           'modified_by', $self->modified_by)
                                          ));
  }

  if ($self->tainted->{users}) {
    foreach my $user (@{ $self->users }) {
      my %relationship = (
                         from    => $self->id,
                         to      => $user->id,
                         level   => 'administrator',
                         status  => 'active'
                       );
      $self->adaptor->add_relationship(%relationship);
    }
  }
}

sub users {
  ### a
  my $self = shift;
  $Users_of{$self} = shift if @_;
  return $Users_of{$self};
}

sub add_user {
  my ($self, $user) = @_;
  if (!$self->is_user_member($user)) {
    push @{ $Users_of{$self} }, $user;
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

sub remove_user {
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
  $Administrators_of{$self} = shift if @_;
  return $Administrators_of{$self};
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
}

}

1;
