package EnsEMBL::Web::Interface::PageDefinition;

use strict;
use warnings;

{

my %Title_of;
my %PageElements_of;
my %FormElements_of;
my %Action_of;
my %OnComplete_of;
my %DataDefinition_of;

sub new {
  my ($class, %params) = @_;
  my $self = bless \my($scalar), $class;
  $Title_of{$self}          = defined $params{title} ? $params{title} : "";
  $OnComplete_of{$self}     = defined $params{on_complete} ? $params{on_complete} : "";
  $PageElements_of{$self}   = defined $params{page_elements} ? $params{page_elements} : [];
  $FormElements_of{$self}   = defined $params{form_elements} ? $params{form_elements} : [];
  $DataDefinition_of{$self} = defined $params{data_definition} ? $params{data_definition} : undef;
  $Action_of{$self}         = defined $params{action} ? $params{action} : undef;
  return $self;
}

sub title {
  ### a
  my $self = shift;
  $Title_of{$self} = shift if @_;
  return $Title_of{$self};
}

sub on_complete {
  ### a
  my $self = shift;
  $OnComplete_of{$self} = shift if @_;
  return $OnComplete_of{$self};
}

sub action {
  ### a
  my $self = shift;
  $Action_of{$self} = shift if @_;
  return $Action_of{$self};
}

sub data_definition {
  ### a
  my $self = shift;
  $DataDefinition_of{$self} = shift if @_;
  return $DataDefinition_of{$self};
}

sub page_elements {
  ### a
  my $self = shift;
  $PageElements_of{$self} = shift if @_;
  return $PageElements_of{$self};
}

sub form_elements {
  ### a
  my $self = shift;
  $FormElements_of{$self} = shift if @_;
  return $FormElements_of{$self};
}

sub label_for_form_element {
  ## TODO: Unify elements and data definitions into single data structure
  my ($self, $name) = @_; 
  foreach my $element (@{ $self->form_elements }) {
    if ($element->{name} eq $name) {
      return $element->{label};
    }  
  }
  return undef;
}

sub add_form_element {
  my ($self, $element, $title) = @_;
  push @{$self->form_elements}, { name => $element, label => $title};
}

sub add_element {
  my ($self, %params) = @_;
  push @{ $self->page_elements }, \%params;
}

sub add_text {
  my ($self, $text) = @_;
  $self->add_element((type => 'text', label => $text, field => undef));
}

sub definition_for_data_field {
  my ($self, $name) = @_;
  foreach my $element (@{ $self->data_definition->fields }) {
    if ($element->{'Field'} eq $name) {
      return $element;
    }
  }
  return undef;
}

sub DESTROY {
  my $self = shift;
  delete $Title_of{$self};
  delete $PageElements_of{$self};
  delete $DataDefinition_of{$self};
  delete $Action_of{$self};
  delete $OnComplete_of{$self};
  delete $FormElements_of{$self};
}

}

1;
