package EnsEMBL::Web::Interface::ZMenuView;

use strict;
use warnings;

use EnsEMBL::Web::Interface::ZMenu;

{

my %Zmenu_of;

sub new {
  ### c
  ### Inside-out class for viewing zmenus. This is the default view class for zmenus. All new {{EnsEMBL::Web::Interface::ZMenu}} objects will use this class' methods for display. You can change this behaviour by replacing the default object by calling {{EnsEMBL::Web::Interface::ZMenu::view}}.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), ref($class) || $class;
  $Zmenu_of{$self} = defined $params{zmenu} ? $params{zmenu} : "";
  return $self;
}

sub zmenu {
  ### a
  my $self = shift;
  $Zmenu_of{$self} = shift if @_;
  return $Zmenu_of{$self};
}

sub linkage {
  ### Returns the zmenu as a contents of an HTML link. Useful for imagemaps.
  my $self = shift;
  my $link = qq(alt="Click for menu" );
  $link .= qq(href="javascript:void(0)" );
  $link .= qq(title="" );
  $link .= qq(onclick=");
  $link .= qq(zmenu\(') . $self->zmenu->title . 
           qq(', 'http://www.apple.com', ') . $self->zmenu->ident . 
           qq('\));
  $link .= qq(");
  return $link;
}

sub text {
  ### Returns a simple string representation of a zmenu.
  my $self = shift;
  return sprintf("%s", $self->zmenu->title);
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Zmenu_of{$self};
}

}

1;
