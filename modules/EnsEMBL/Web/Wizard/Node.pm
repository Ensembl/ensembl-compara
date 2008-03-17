package EnsEMBL::Web::Wizard::Node;

use strict;
use warnings;

use Class::Std;

{

my %Type :ATTR(:set<type> :get<type> :init_arg<type>);
my %Title :ATTR(:set<title> :get<title>);
my %Name :ATTR(:set<name> :get<name> :init_arg<name>);
my %Object :ATTR(:set<object> :get<object> :init_arg<object>);
my %Elements :ATTR(:set<elements> :get<elements> :init_arg<elements>);
my %TextAbove :ATTR(:set<textabove> :get<textabove>);
my %TextBelow :ATTR(:set<textbelow> :get<textbelow>);

sub BUILD {
  ### c
  ### Creates a new inside-out Node object. These objects are linked together
  ### to form a wizard interface controlled by the
  ### {{EnsEMBL::Web::Wizard}} class.
  my ($self, $ident, $args) = @_;
  $self->set_type($args->{type});
  $self->set_name($args->{name});
  $self->set_object($args->{object});
  $self->set_elements([]);
}

sub type {
  ### a
  my $self = shift;
  $self->set_type(shift) if @_;
  return $self->get_type;
}

sub title {
  ### a
  my $self = shift;
  $self->set_title(shift) if @_;
  return $self->get_title;
}

sub name {
  ### a
  my $self = shift;
  $self->set_name(shift) if @_;
  return $self->get_name;
}

sub object {
  ### a
  my $self = shift;
  $self->set_object(shift) if @_;
  return $self->get_object;
}

sub elements {
  ### a
  my $self = shift;
  $self->set_elements(shift) if @_;
  return $self->get_elements;
}

sub text_above {
  ### a
  my $self = shift;
  $self->set_textabove(shift) if @_;
  return $self->get_textabove;
}

sub text_below {
  ### a
  my $self = shift;
  $self->set_textbelow(shift) if @_;
  return $self->get_textbelow;
}

sub add_element {
  my( $self, %options ) = @_;
  push @{ $self->elements }, \%options;
}

}

1;
