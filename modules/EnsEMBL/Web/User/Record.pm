package EnsEMBL::Web::User::Record;

use strict;
use warnings;
use EnsEMBL::Web::Record;
use EnsEMBL::Web::DBSQL::UserDB;

our @ISA = qw(EnsEMBL::Web::Record);

{

my %User_of;
my %Type_of;

sub new {
  ### c
  my ($class, %params) = @_;
  my $self = $class->SUPER::new(%params);
  $Type_of{$self} = defined $params{'type'} ? $params{'type'} : "record";
  $User_of{$self} = defined $params{'user'} ? $params{'user'} : 0;
  if (!$self->adaptor) {
    $self->adaptor(EnsEMBL::Web::DBSQL::UserDB->new());
  }
  return $self;
}

sub type {
  ### a
  my $self = shift;
  $Type_of{$self} = shift if @_;
  return $Type_of{$self};
}

sub user {
  ### a
  my $self = shift;
  $User_of{$self} = shift if @_;
  return $User_of{$self};
}

sub delete {
  my $self = shift;
  $self->adaptor->delete_record((
                                  id => $self->id
                               ));
}

sub save {
  my $self = shift;
  my $dump = $self->dump_data;
  if ($self->id) {
    $self->adaptor->update_record((
                                    id => $self->id,
                                  user => $self->user,
                                  type => $self->type,
                                  data => $dump
                                 ));
  } else {
    $self->adaptor->insert_record((
                                  user => $self->user,
                                  type => $self->type,
                                  data => $dump
                                 ));
  }
  return 1;
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Type_of{$self};
  delete $User_of{$self};
}

}

1;
