package EnsEMBL::Web::Interface::ZMenuCollection;

use strict;
use warnings;

use EnsEMBL::Web::Interface::ZMenu;

{

my %Collection_of;

sub new {
  ### c
  ### Inside-out class for managing collections of z-menu content. 
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Collection_of{$self} = defined $params{collection} ? $params{collection} : [];
  return $self; 
} 

sub process {
  ### Processes zmenu items. Takes two arrays as parameters, one with a list of ZMenuItems to add to the zmenu, and one with a list of names to remove.
  my ($self, $add, $remove) = @_;
  push @{ $self->collection }, @{ $add };
  my @collection = @{ $self->collection };
  my $index = 0;
  my $other_removal = 0;
  foreach my $name (@{ $remove }) {
    $index = 0;
    foreach my $item ( @collection ) {  
      if ($item->name eq $name) {
        splice(@{ $self->collection }, ($index - $other_removal), 1);
        $other_removal++;
        #$self->remove($name);
      }
      $index++;
    } 
  }
}

sub object_with_name {
  ### Returns a reference to a ZMenuItem object with a specific name. Returns the first object with a name if more than one with that name is present.
  my ($self, $name) = @_;
  my $return_object = undef;
  foreach my $object ( @{ $self->collection }) {
    if ($object->name eq $name) { 
      $return_object = $object; 
      last;
    }
  }
  return $return_object;
}

sub object_index_with_name {
  ### Returns the index of an object with a given name.
  my ($self, $name) = @_;
  my $count = 0;
  my $found = 0;
  foreach my $object ( @{ $self->collection }) {
    if ($object->name eq $name) { 
      $found = 1;
      last;
    }
    $count++;
  }
  if ($found) {
    return $count;
  } else {
    return -1;
  }
}

sub linkage {
  ### Returns javascript link used in image maps.
  my ($self, $zmenu) = @_;
  my $link = qq(alt="Click for menu" );
  $link .= qq(href="#" );
  $link .= qq(title="AJAX" );
  $link .= qq(onclick=");
  $link .= qq(menu\(') . $self->json($zmenu) .
           qq('\));
  $link .= qq(");
  return $link;
}

sub json {
  my ($self, $zmenu, %parameters) = @_;
  my $json = "";
  $json = "{ menu: { title: '" . $zmenu->title .
                 "', ident: '" . $zmenu->ident .
               "', species: '" . $ENV{ENSEMBL_SPECIES} .
                  "', type: '" . $zmenu->type . "', items: [";

  foreach my $item (@{ $self->content }) {
    $json .= " { text: '" . $item->display . "' }, ";
  }

  $json .= "] } }";
  if (!$parameters{escape} || $parameters{escape}  eq "yes") {
    $json =~ s/'/\\'/g;
  }
  warn "JSON: " . $json;
  return $json;
}

sub content {
  my $self = shift; 
  return $self->collection;
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
