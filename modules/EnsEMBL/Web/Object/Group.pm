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
my %Users_of;

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
  $Users_of{$self} = defined $params{'users'} ? $params{'users'} : undef;
  return $self;
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
    $self->adaptor->update_group(%params);
  } else {
    warn "INSERTING NEW GROUP";
    $self->id($self->adaptor->insert_group(%params));
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
  push @{ $Users_of{$self} }, $user;
  $self->taint('users');
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


sub DESTROY {
  my $self = shift;
  delete $Name_of{$self};
  delete $Description_of{$self};
  delete $Type_of{$self};
  delete $Status_of{$self};
  delete $CreatedBy_of{$self};
  delete $ModifiedBy_of{$self};
}

}

1;
