package EnsEMBL::Web::Interface::ZMenuCollection;

use strict;
use warnings;

use EnsEMBL::Web::Interface::ZMenu;

{

my %Collection_of;

sub new {
  ### c
  ### Inside-out class for managing collections of z-menus. You can
  ### add new ZMenu objects to the collection by calling {{add}}.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Collection_of{$self} = defined $params{collection} ? $params{collection} : [];
  return $self; 
} 

sub add_zmenu {
  ### Creates a new zmenu and adds it to the collection.
  my ($self, %params) = @_;
  push @{ $self->collection }, EnsEMBL::Web::Interface::ZMenu->new(%params);
}

sub size {
  ### Returns the number of zmenus in the collection.
  my $self = shift;
  my @array = @{ $self->collection };
  return ($#array + 1);
}

sub zmenu_by_title {
  ### Returns a zmenu object {{EnsEMBL::Web::Interface::ZMenu}} 
  ### with a given name from the collection.
  my ($self, $name) = @_;
  my $return_menu;
  foreach my $zmenu (@{ $self->collection }) {
    if ($zmenu->title eq $name) {
      $return_menu = $zmenu;
    }
  }
  return $return_menu;
}

sub collection {
  ### a
  my $self = shift;
  $Collection_of{$self} = shift if @_;
  return $Collection_of{$self};
}

sub DESTROY {
  ### d
  my ($self) = shift;
  delete $Collection_of{$self};
}

}

1
