package EnsEMBL::Web::DOM::Node::Element;

use strict;

use base qw(EnsEMBL::Web::DOM::Node);

use constant {
  ELEMENT_TYPE_BLOCK_LEVEL => 1,
  ELEMENT_TYPE_INLINE      => 2,
  ELEMENT_TYPE_TOP_LEVEL   => 3,
  ELEMENT_TYPE_HEAD_ONLY   => 4,
  ELEMENT_TYPE_SCRIPT      => 5,
  SELF_CLOSING_TAGS        => { area => 1, base => 1, br => 1, col => 1, frame => 1, hr => 1, img => 1, input => 1, link => 1, meta => 1, param => 1 }
};

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
  return $self->can_have_child ? "<$tag$attributes>".$self->inner_HTML."</$tag>" : "<$tag$attributes />";
}

sub can_have_child {
  ## Checks if the element can have child nodes or not - depending upon node_name
  ## @return 1/0 accordingly
  return !$_[0]->SELF_CLOSING_TAGS->{$_[0]->node_name};
}

sub element_type {
  ## Tells us the element type
  ## @return Constant corresponding to the element type
  my $self = shift;
  return $self->ELEMENT_TYPE_BLOCK_LEVEL if grep { $self->node_name eq $_ } qw(address blockquote div dl fieldset form h1 h2 h3 h4 h5 h6 hr noscript ol p pre table ul dd dt li tbody td tfoot th thead tr);
  return $self->ELEMENT_TYPE_TOP_LEVEL   if grep { $self->node_name eq $_ } qw(html head body);
  return $self->ELEMENT_TYPE_HEAD_ONLY   if grep { $self->node_name eq $_ } qw(title meta style base link);
  return $self->ELEMENT_TYPE_SCRIPT      if $self->node_name eq 'script';
  return $self->ELEMENT_TYPE_INLINE;
}

sub w3c_appendable {
  ## Checks if the given node can be appended to the element according to the w3c rules
  ## Override this in child class if there are any specific rules for a specific node name
  ## @param Node object to be appended
  my ($self, $child) = @_;
  my $se = $self->element_type;
  my $e  = $self->ELEMENT_NODE;
  my $t  = $self->TEXT_NODE;
  my $et = $self->ELEMENT_TYPE_TOP_LEVEL;
  my $eb = $self->ELEMENT_TYPE_BLOCK_LEVEL;
  my $ei = $self->ELEMENT_TYPE_INLINE;
  my $eh = $self->ELEMENT_TYPE_HEAD_ONLY;
  my $es = $self->ELEMENT_TYPE_SCRIPT;
  my $cn = $child->node_type;
  my $ce = $cn == $e ? $child->element_type : undef;

  return
    $se == $ei && ($cn == $e && $ce == $ei || $cn == $t) ||
    $se == $eb && ($cn == $e && ($ce == $eb || $ce == $ei || $ce == $es) || $cn == $t) ||
    $se == $et && ($cn == $e && $ce != $ei) ||
    $se == $eh && ($cn == $t)
  ? 1 : 0;
}

sub attributes {
  ## Getter for all attribute names
  ## @return ArrayRef of all attribute names
  return [keys %{shift->{'_attributes'}}];
}

sub get_attribute {
  ## Gets attribute of the element
  ## @param Attribute name
  ## @return Attribute value if attribute exists, blank string otherwise
  my ($self, $attrib) = @_;

  return '' unless exists $self->{'_attributes'}{$attrib};

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
    return $self->{'_attributes'}{$attrib};
  }
  return join ' ', @values;
}

sub has_attribute {
  ## Checks if an attribute exists
  ## @param Attribute name
  ## @return 1 if attribute exists, 0 otherwise
  my ($self, $attrib) = @_;
  return exists $self->{'_attributes'}{$attrib} ? 1 : 0;
}

sub remove_attribute {
  ## Removes attribute of the element
  ## If attribute can contain multiple values, and value agrument is provided, removes given value only
  ## @param Attribute name
  ## @param Attribute value
  ## @return No return value
  my ($self, $attrib, $value) = @_;
  
  return unless exists $self->{'_attributes'}{$attrib};
  
  if (defined $value && ref($self->{'_attributes'}{$attrib}) eq 'HASH') {
    delete $self->{'_attributes'}{$attrib}{$value} if exists $self->{'_attributes'}{$attrib}{$value};
    return if scalar keys %{$self->{'_attributes'}{$attrib}}; #don't remove attribute completely if some keys present
  }
  delete $self->{'_attributes'}{$attrib};
}

sub set_attribute {
  ## Sets attribute of the element
  ## @param Attribute name
  ## @param Attribute value
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
  ## @param HashRef {attrib1 => ?, attrib2 => ? ...}
  my ($self, $attribs) = @_;
  $self->set_attribute($_, $attribs->{$_}) for (keys %$attribs);
}

sub _access_attribute {
  ## Accessor for attributes that have same value and name (eg disabled="disabled", checked="checked")
  ## @param Attribute name
  ## @param Flag to set or remove attribute
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
  ## @param Id
  ## @return Id
  my ($self, $id) = @_;
  $self->set_attribute('id', $id) if $id;
  return $self->get_attribute('id');
}

sub name {
  ## Getter/Setter of name attribute
  ## @param Name
  ## @return Name
  my ($self, $name) = @_;
  $self->set_attribute('name', $name) if $name;
  return $self->get_attribute('name');
}

sub inner_HTML {
  ## Sets/Gets inner HTML of an element
  ## If intended to set parsed HTML, string is converted to tree format and appended to the node after removing the existing child nodes.
  ## @param innerHTML string
  ## @param flag to tell whether or not to parse the HTML - off (no parsing) by default.
  ## @return final HTML string
  my ($self, $html, $do_parse) = @_;
  if (defined $html) {
    $self->remove_children;
    if ($do_parse) {
      $self->append_child($_) for @{$self->_parse_HTML_to_nodes($html)};
    }
    else {
      $self->{'_text'} = $html;
    }
  }
  return $self->{'_text'} if $self->{'_text'} ne '';
  $html  = '';
  $html .= $_->render for @{$self->{'_child_nodes'}};
  return $html;
}

sub inner_text {
  ## Sets/Gets inner text (after encoding any HTML entities if found)
  ## If intended to set text, a new text node is added with the given text, and any existing child nodes are removed
  ## @param text
  ## @return Inner Text for all the text nodes found inside.
  my ($self, $text) = @_;
  if (defined $text) {
    $self->remove_children;
    $self->append_child($self->dom->create_text_node($text));
  }
  my $text = '';
  $text .= $_->render for @{$self->get_nodes_by_node_type($self->TEXT_NODE)};
  return $text;
}

sub add_attribute {
  #warn "Use set_attribute(), not add_attribute()!";
  return shift->set_attribute(@_);
}

sub _parse_HTML_to_nodes {
  ## private method used in &inner_HTML
  ## function to parse HTML from a string to tree structure
  my ($self, $html) = @_;

  my $nodes = [];
  my @raw_nodes;
  my @tags;
  my @lifo;

  my $current_node;

  while ($html =~ /(<(\/?)(\w+)((\s+\w+(\s*=\s*(?:".*?"|'.*?'|[^'">\s]+))?)+\s*|\s*)(\/?)>)/g) {
    my $tag = {
      'string'  => $1,
      'start'   => $-[1],
      'end'     => $+[1],
      'name'    => $3,
      'type'    => $2 eq '' ? $7 eq '' ? 'start_tag' : 'selfclosing_tag' : 'end_tag',
      'attr'    => {}
    };
    my $atts = $4;
    $tag->{'attr'}{$1} = $2 while $atts =~ /(\w+)\s*=\s*"([^"]*)"/g;
    push @tags, $tag;
  }

  # construct raw nodes
  my $text_length = scalar @tags ? $tags[0]->{'start'} : length $html;
  push @raw_nodes, {'type' => 'text', 'text' => substr($html, 0, $text_length)} if $text_length;
  for (0..$#tags) {
    push @raw_nodes, $tags[$_];
    $text_length = ($_ < $#tags ? $tags[$_ + 1]->{'start'} : length $html) - $tags[$_]->{'end'};
    push @raw_nodes, {'type' => 'text', 'text' => substr($html, $tags[$_]->{'end'}, $text_length)} if $text_length;
    delete $tags[$_];
  }

  # convert raw nodes to Node objects
  for (@raw_nodes) {
    if ($_->{'type'} eq 'text') {
      my $node = $self->dom->create_text_node($_->{'text'});
      $current_node ? $current_node->append_child($node) : push @$nodes, $node;
    }
    elsif ($_->{'type'} eq 'end_tag') {
      my $expected = pop @lifo;
      $current_node = $current_node->parent_node, next if ($_->{'name'} eq $expected);
      warn "HTML parsing error: Unexpected closing tag found - ".$_->{'name'}." as in ".$_->{'string'}.", expected ".($expected || 'no')." tag.";
      return [];
    }
    else {
      my $node = $self->dom->create_element($_->{'name'}, $_->{'attr'}, 1);
      if (!$node) {
        warn "HTML parsing error: Could not create HTML element '".$_->{'name'}."' from ".$_->{'string'};
        return [];
      }
      $current_node ? $current_node->append_child($node) : push @$nodes, $node;
      push @lifo, $_->{'name'} and $current_node = $node if $_->{'type'} eq 'start_tag';
    }
  }
  
  return $nodes;
}

1;