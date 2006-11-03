package EnsEMBL::Web::DBSQL::DataDefinition;

use strict;
use warnings;

{

my %Fields_of;
my %Adaptor_of;

sub new {
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Fields_of{$self}   = defined $params{fields} ? $params{fields} : [];
  $Adaptor_of{$self}   = defined $params{adaptor} ? $params{adaptor} : [];
  return $self;
}

sub fields {
  ### a
  my $self = shift;
  $Fields_of{$self} = shift if @_;
  return $Fields_of{$self};
}

sub discover {
  my $self = shift;
  $self->fields($self->adaptor->discover);
}

sub adaptor {
  ### a
  my $self = shift;
  $Adaptor_of{$self} = shift if @_;
  return $Adaptor_of{$self};
}

sub add_field {
  my ($self, $field) = @_;
  push @{ $self->fields }, $field;
}

sub DESTROY {
  my $self = shift;
  delete $Fields_of{$self};
  delete $Adaptor_of{$self};
}


 
}

1;
