package EnsEMBL::Web::DOM;

### Serves as an accessor of the DOM tree
### Status - Under Development - hr5

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Root);
use EnsEMBL::Web::DOM::Node::Text;
sub new {
  ## @constructor
  return bless {
    '_classes'  => {},
  }, shift;
}

sub map_element_class {
  ## Maps an element type with a class
  ## When create_element is called with a given element type, the mapped class is instantiated.
  my ($self, $map) = @_;
  for (keys %$map) {
    $self->{'_classes'}{ $_ } = $map->{ $_ };
  }
}

sub create_document {
  ## Creates document node
  ## @return Node::Document object
  my $self = shift;
  my $node_class = 'EnsEMBL::Web::DOM::Node::Document';
  $self->dynamic_use($node_class);
  return $node_class->new($self);
}

sub create_element {
  ## Creates an element of a given tag name by instantiating the corresponding class
  ## @params Element type
  ## @return Element subclass object
  my ($self, $element_type)  = @_;

  my $node_class = $self->_get_mapped_element_class(lc $element_type);
  my $valid_element = $self->dynamic_use($node_class);
  
  unless ($valid_element) {
    warn qq(Could not create an element $element_type. Unable to load $node_class dynamically.);
    return;
  }
  return $node_class->new($self);
}

sub create_text_node {
  ## Creates a text node
  ## @return Text node object
  my $self = shift;
  #my $node_class = 'EnsEMBL::Web::DOM::Node::Text';
  #$self->dynamic_use($node_class);
  return EnsEMBL::Web::DOM::Node::Text->new($self);
}

sub create_comment {
  ## Creates comment
  ## @return Comment object
  my $self = shift;
  my $node_class = 'EnsEMBL::Web::DOM::Node::Comment';
  $self->dynamic_use($node_class);
  return $node_class->new($self);
}

sub _get_mapped_element_class {
  my ($self, $element_type) = @_;
  return $self->{'_classes'}{ $element_type } if exists $self->{'_classes'}{ $element_type };
  return 'EnsEMBL::Web::DOM::Node::Element::Input::'.ucfirst $1 if $element_type =~ /^input([a-z]+)$/;
  return 'EnsEMBL::Web::DOM::Node::Element::'.ucfirst $element_type;
}

1;