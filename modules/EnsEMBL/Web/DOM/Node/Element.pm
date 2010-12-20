package EnsEMBL::Web::DOM::Node::Element;

use strict;

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

  my $tag         = $self->node_name;
  my $attributes  = '';
  $attributes    .= sprintf(' %s="%s"', $_, $self->get_attribute($_)) for keys %{$self->{'_attributes'}};
  return qq(<$tag$attributes />) unless $self->can_have_child;

  my $children = $self->inner_HTML;
  if ($children eq '') { #inner html has priority over child nodes
    $children .= $_->render for @{$self->child_nodes};
  }
  return qq(<$tag$attributes>$children</$tag>);
}

sub attributes {
  ## Getter for all attribute names
  ## @return ArrayRef of all attribute names
  return [keys %{shift->{'_attributes'}}];
}

sub get_attribute {
  ## Gets attribute of the element
  ## @params Attribute name
  ## @return Attribute value if attribute exists, blank string otherwise
  my ($self, $attrib) = @_;

  return '' unless $self->has_attribute($attrib);

  my @values;
  if ($attrib eq 'style') {
    while (my ($style_name, $style_value) = each %{$self->{'_attributes'}{$attrib}}) {
      push @values, qq($style_name:$style_value;);
    }
  }
  elsif ($attrib eq 'class') {
    @values = keys %{$self->{'_attributes'}{$attrib}};
  }
  else {
    push @values, $self->{'_attributes'}{$attrib};
  }
  return join ' ', @values;
}

sub has_attribute {
  ## Checks if an attribute exists
  ## @params Attribute name
  ## @return 1 if attribute exists, 0 otherwise
  my ($self, $attrib) = @_;
  return exists $self->{'_attributes'}{$attrib} ? 1 : 0;
}

sub remove_attribute {
  ## Removes attribute of the element
  ## If attribute can contain multiple values, and value agrument is provided, removes given value only
  ## @params Attribute name
  ## @params Attribute value
  ## @return No return value
  my ($self, $attrib, $value) = @_;
  
  return unless $self->has_attribute($attrib);
  
  if (defined $value && ref($self->{'_attributes'}{$attrib}) eq 'HASH') {
    delete $self->{'_attributes'}{$attrib}{$value} if exists $self->{'_attributes'}{$attrib}{$value};
    return if scalar keys %{$self->{'_attributes'}{$attrib}}; #don't remove attribute completely if some keys present
  }
  delete $self->{'_attributes'}{$attrib};
}

sub set_attribute {
  ## Sets attribute of the element
  ## @params Attribute name
  ## @params Attribute value
  ## @return No return value
  my ($self, $attrib, $value) = @_;

  return unless defined $value;
  $value  =~ s/^\s+|\s+$//g; #trim
  $attrib = lc $attrib;

  if ($attrib =~ /^(class|style)$/) {
    my $delimiter = {'class' => qr/\s+/, 'style' => qr/\s*;\s*/};
    $self->{'_attributes'}{$attrib} = {} unless defined $self->{'_attributes'}{$attrib};
    for (split $delimiter->{$attrib}, $value) {
      my ($key, $val) = $attrib eq 'style' ? split /\s*:\s*/, $_ : ($_, 1);
      $self->{'_attributes'}{$attrib}{$key} = $val if $key;
    }
  }
  else {
    $self->{'_attributes'}{$attrib} = $value;
  }
}

sub set_attributes {
  ## Sets multiple attributes to the element
  ## @params HashRef {attrib1 => ?, attrib2 => ? ...}
  my ($self, $attribs) = @_;
  $self->set_attribute($_, $attribs->{$_}) for (keys %$attribs);
}

sub _access_attribute {
  ## Accessor for attributes that have same value and name (eg disabled="disabled", checked="checked")
  ## @params Attribute name
  ## @params Flag to set or remove attribute
  ## Use in required child classes
  my $self    = shift;
  my $attrib  = shift;

  if (@_) {
    if (shift == 1) {
      $self->set_attribute($attrib, $attrib);
    }
    else {
      $self->remove_attribute($attrib);
    }
  }
  return $self->has_attribute($attrib) ? 1 : 0;
}

sub id {
  ## Getter/Setter of id attribute
  ## @params Id
  ## @return Id
  my ($self, $id) = @_;
  $self->set_attribute('id', $id) if $id;
  return $self->get_attribute('id');
}

sub name {
  ## Getter/Setter of name attribute
  ## @params Name
  ## @return Name
  my ($self, $name) = @_;
  $self->set_attribute('name', $name) if $name;
  return $self->get_attribute('name');
}

sub inner_HTML {
  ## Sets/Gets inner HTML of an element
  ## This intends to remove all the child elements before setting inner HTML - use document->create_text_node in other case.
  ## Any elements added by this methods will not be accessible with selector methods
  ## @params innerHTML
  ## @return innerHTML
  my $self = shift;
  if (@_) {
    $self->{'_child_nodes'} = [];
    $self->{'_text'} = shift;
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