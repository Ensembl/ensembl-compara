package EnsEMBL::Web::DOM::Node::Element;

## Status - Under Development
## TODO - appendable()

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::DOM::Node);

sub node_type {
  ## @overrides
  return shift->ELEMENT_NODE;
}

sub render {
  ## Outputs the element html
  ## @overrides
  ## @return HTML
  my $self = shift;

  my $tag = $self->node_name;
  
  #attribute W3C validation - generate warning only
  for (@{ $self->mandatory_attributes }) {
    #warn "Attribute $_ missing for tag $tag - will cause error in W3C validation." unless exists $self->{'_attributes'}{ $_ };
  }

  my $attributes = [];
  foreach my $attrib (keys %{ $self->{'_attributes'} }) {
    my $glue = {'class' => ' ', 'style' => ';'};
    push @$attributes, sprintf(
      '%s="%s"',
      $attrib,
      $attrib =~ /^(class|style)$/ ? join($glue->{ $attrib }, keys(%{ $self->{'_attributes'}{ $attrib } })) : $self->{'_attributes'}{ $attrib }
    );
  }
  $attributes = join ' ', @$attributes;
  return qq(<$tag $attributes />) unless $self->can_have_child;
  
  my $children = '';
  if ($self->inner_HTML ne '') {
    $children = $self->inner_HTML;
  }
  else {
    $children .= $_->render for (@{ $self->child_nodes });
  }
  return qq(<$tag $attributes>$children</$tag>);
}

sub validate_attribute {
  ## Validates attribute value
  ## Override this in child class
  ## @params ScalarRef to attrib name
  ## @params ScalarRef to attrib value
  ## @return 0 only if a value could not be validated, 1 always otherwise
  return 1;
}

sub allowed_attributes {
  ## Gives an arrayref of all allowed attributes
  ## Override this in child class to append more attributes to the list
  ## @return arrayref of all allowed attributes (strings)
  return ['id', 'class', 'title', 'style', 'dir', 'lang', 'xml:lang'];
}

sub mandatory_attributes  {
  ## Returns an array of attributes declared mandatory by W3C for this given node name
  ## Override in child class
  ## @return ArrayRef of strings (attributes)
  return [];
}

sub attributes {
  ## Getter for attributes
  ## @return HashRef of all attributes - {'name1' => 'value1', 'name1' => 'value1'}
  return shift->{'_attributes'};
}

sub get_attribute {
  ## Gets attribute of the element
  ## @params Attribute name
  ## @return Attribute value if attribute exists, blank string otherwise
  my ($self, $attrib) = @_;
  return $self->{'_attributes'}{ $attrib } || '';
}

sub has_attribute {
  ## Checks if an attribute exists
  ## @params Attribute name
  ## @return 1 if attribute exists, 0 otherwise
  my ($self, $attrib) = @_;
  return exists $self->{'_attribiutes'}{ $attrib } ? 1 : 0;
}

sub remove_attribute {
  ## Removes attribute of the element
  ## If attribute can contain multiple values, and value agrument is provided, removes given value only
  ## @params Attribute name
  ## @params Attribute value
  ## @return No return value
  my ($self, $attrib, $value) = @_;
  
  return unless exists $self->{'_attributes'}{ $attrib };
  
  if (defined $value && ref($self->{'_attributes'}{ $attrib }) eq 'HASH') {
    delete $self->{'_attributes'}{ $attrib }{ $value } if exists $self->{'_attributes'}{ $attrib }{ $value };
    return if scalar keys %{ $self->{'_attributes'}{ $attrib } }; #don't remove attribute completely if some keys present
  }
  delete $self->{'_attributes'}{ $attrib };
}

sub set_attribute {
  ## Sets attribute of the element
  ## @params Attribute name
  ## @params Attribute value
  ## @return No return value
  my ($self, $attrib, $value) = @_;

  $attrib = lc $attrib;
  my $allowed_attributes = { map { $_ => 1 } @{ $self->allowed_attributes } };
  
  unless (
    exists $allowed_attributes->{ $attrib } &&      #allowed as an attribute  - if no problem with attribute name
    $self->validate_attribute(\$attrib, \$value)    #validated                - if no problem with attribute value
  ) {
    warn "Could not set attribute $attrib with value $value for tag <".$self->node_name.">.";
    return;
  }

  if ($attrib =~ /^(class|style)$/) {
    return unless $value;
    $self->{'_attributes'}{ $attrib } = {} unless defined $self->{'_attributes'}{ $attrib };
    $self->{'_attributes'}{ $attrib }{ $_ } = 1 for split(' ', $value);  #does not allow any duplicates
  }
  else {
    $self->{'_attributes'}{ $attrib } = $value if defined $value;
  }
}

sub _access_attribute {
  ## Accessor for attribute which have same value and name (eg disabled="disabled")
  ## Use in required child classes
  my $self    = shift;
  my $attrib  = shift;

  if (@_) {
    if (shift == 0) {
      $self->remove_attribute($attrib);
    }
    else {
      $self->set_attribute($attrib, $attrib);
    }
  }
  return $self->has_attribute($attrib) ? 1 : 0;
}

sub id {
  ## Getter/Setter of id attribute
  ## @params Id
  ## @return Id
  my ($self, $id) = @_;
  if ($id) {
    my $old_id = $self->id || '';
    $self->set_attribute('id', $id);
  }
  return $self->get_attribute('id');
}

sub name {
  ## Getter/Setter of name attribute
  ## @params Name
  ## @return Name
  my ($self, $name) = @_;
  if ($name) {
    my $old_name = $self->name || '';
    $self->set_attribute('name', $name);
  }
  return $self->get_attribute('name');
}

sub inner_HTML {
  ## Sets/Gets inner HTML of an element
  ## This will remove all the child elements - use document->create_text_node to avoid that.
  ## Any elements added by this methods will not be accessible from DOM (nor be validated)
  ## @params innerHTML
  ## @return innerHTML
  my $self = shift;
  if (@_) {
    $self->{'_text'} = shift;
    $self->{'_child_nodes'} = [];
  }
  return $self->{'_text'};
}

sub inner_text {
  ## Sets/Gets inner text (after encoding any HTML entities if found)
  ## Use this instead of inner_HTML if HTML encoding is required
  ## @params text
  ## @return text
  my $self = shift;
  $self->{'_text'} = $self->encode_htmlentities(shift) if @_;
  return $self->decode_htmlentities($self->inner_HTML);
}

sub add_attribute {
  #warn "Use set_attribute(), not add_attribute()!";
  return shift->set_attribute(@_);
}

1;

