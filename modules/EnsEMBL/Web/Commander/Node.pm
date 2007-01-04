package EnsEMBL::Web::Commander::Node;

use strict;
use warnings;

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
    $html .= $element->{'content'} . "<br/><br />\n";
  }
  return $html;
}

sub add_option {
  my ($self, %params) = @_;
  my $name = $params{name};
  my $value = $params{value};
  my $label = $params{label};
  my $selected = $params{selected};
  my $html = "";
  $html .= "<input type='radio' value='$value' name='$name' id='$name" . "_" . "$value'";
  if ($selected) {
    $html .= " checked";
  }
  $html .= "> $label";
  $self->add_element(( name => $name, content => $html )); 
}

sub add_text_field {
  my ($self, %params) = @_;
  my $name = $params{name};
  my $value = $params{value};
  my $label = $params{label};
  my $html = "";
  $html .= "$label<br />\n";
  $html .= "<input type='text' value='$value' name='$name' id='$name'>";
  $self->add_element(( name => $name, content => $html )); 
}

sub add_text {
  my ($self, %params) = @_;
  $self->add_element(( name => $params{name}, content => $params{content} )); 
}

sub add_element {
  my ($self, %params) = @_;
  push @{ $self->elements }, { name => $params{name}, content => $params{content} };
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
