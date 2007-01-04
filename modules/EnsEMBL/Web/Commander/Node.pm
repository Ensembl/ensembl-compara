package EnsEMBL::Web::Commander::Node;

use strict;
use warnings;

use EnsEMBL::Web::Form::Element::Header;
use EnsEMBL::Web::Form::Element::String;
use EnsEMBL::Web::Form::Element::RadioButton;

{

my %Title_of;
my %Name_of;
my %Elements_of;

sub new {
  ### c
  ### Creates a new inside-out Node object. These objects are linked
  ### togeter to form a wizard interface controlled by the 
  ### {{EnsEMBL::Web::Commander}} class.
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Title_of{$self} = defined $params{title} ? $params{title} : "Node";
  $Name_of{$self} = defined $params{name} ? $params{name} : "Node";
  $Elements_of{$self} = defined $params{elements} ? $params{elements} : [];
  return $self;
}

sub render {
  my ($self, %parameters) = @_;
  my $html = "";
  $html .= "<h2>" . $self->title . "</h2>\n";
  foreach my $element (@{ $self->elements }) {
    if ($parameters{$element->name}) {
      $element->value = $parameters{$element->name};
    }
    $html .= $element->render . "<br/><br />\n";
  }
  return $html;
}

sub add_option {
  my ($self, %params) = @_;
  my $element = EnsEMBL::Web::Form::Element::RadioButton->new();
  $element->value = $params{value};
  $element->name = $params{name};
  $element->id = $params{name} . "_" . $params{value};
  $element->introduction = $params{label};
  if ($params{selected}) {
    $element->checked = 1;
  }
  $self->add_element($element); 
}

sub add_text_field {
  my ($self, %params) = @_;
  my $element = EnsEMBL::Web::Form::Element::String->new();
  $element->name = $params{name};
  $element->value = $params{value};
  $element->introduction = $params{label} . "<br />";
  $self->add_element($element); 
}

sub add_text {
  my ($self, %params) = @_;
  my $element = EnsEMBL::Web::Form::Element::Header->new();
  $element->value = $params{content};
  $self->add_element($element); 
}

sub add_element {
  my ($self, $element) = @_;
  push @{ $self->elements }, $element;
}

## accessors

sub title {
  ### a
  my $self = shift;
  $Title_of{$self} = shift if @_;
  return $Title_of{$self};
}

sub name {
  ### a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub elements {
  ### a
  my $self = shift;
  $Elements_of{$self} = shift if @_;
  return $Elements_of{$self};
}

sub is_final {
  return 0;
}

sub DESTROY {
  ### d
  my $self = shift;
  delete $Title_of{$self};
  delete $Elements_of{$self};
  delete $Name_of{$self};
}

}

1;
