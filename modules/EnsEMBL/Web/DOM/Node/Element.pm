=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::DOM::Node::Element;

use strict;

use EnsEMBL::Web::Exceptions;

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
  ## Call this only in the end to get the actual HTML for the node as it destroys the node afterwards (use outer_HTML for other uses)
  ## @overrides
  ## @return HTML
  my $self = shift;

  my $tag         = $self->node_name;
  my $attributes  = join '', map {sprintf(' %s="%s"', $_, $self->get_attribute($_))} keys %{$self->{'_attributes'}};

  my $html        = $self->can_have_child
    ? sprintf('<%s%s>%s</%1$s>', $tag, $attributes, $self->{'_text'} ne '' ? $self->{'_text'} : join('', map {$_->render} @{$self->{'_child_nodes'}}))
    : qq(<$tag$attributes />);

  # Clear unwanted references (this will make sure circular references are removed allowing object to DESTROY afterwards)
   $self->remove_children;

  return $html;
}

sub render_text {
  ## Outputs the text version of the element's html
  ## @overrides
  ## @return text
  my $self = shift;

  return $self->{'_text'} if $self->{'_text'} ne '';

  my $text = '';
  $text .= sprintf('%s%s', $_->render_text, $_->node_name eq 'br' || $_->node_type eq $self->ELEMENT_NODE && $_->element_type eq $self->ELEMENT_TYPE_BLOCK_LEVEL && $_->next_sibling ? "\n" : '') for @{$self->child_nodes};
  return $text;
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
  $self->node_name eq $_ and return $self->ELEMENT_TYPE_BLOCK_LEVEL for qw(address blockquote div dl fieldset form h1 h2 h3 h4 h5 h6 hr noscript ol p pre table ul dd dt li tbody td tfoot th thead tr);
  $self->node_name eq $_ and return $self->ELEMENT_TYPE_TOP_LEVEL   for qw(html head body);
  $self->node_name eq $_ and return $self->ELEMENT_TYPE_HEAD_ONLY   for qw(title meta style base link);
  $self->node_name eq $_ and return $self->ELEMENT_TYPE_SCRIPT      for qw(script);
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
  ## @return 1 if attribute exists, undef otherwise
  my ($self, $attrib) = @_;
  return exists $self->{'_attributes'}{$attrib} ? 1 : undef;
}

sub has_class {
  ## Checks if class attribute contains the given value
  ## @param Class value
  ## @return 1 if class exists, undef otherwise
  my ($self, $class) = @_;
  return exists $self->{'_attributes'}{'class'} && exists $self->{'_attributes'}{'class'}{$class} ? 1 : undef;
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
  ## @param Attribute value can be any of the following
  ##   String value
  ##   Arrayref of [String, flag], where flag iif on, will html-encode the value
  ##   Arrayref for 'class' for accommodating multiple classnames
  ##   Hashref for 'style' attrib
  ## @return No return value
  my ($self, $attrib, $value) = @_;

  return unless defined $value;

  $attrib = lc $attrib;

  if ($attrib =~ /^(class|style)$/) {
    $self->{'_attributes'}{$attrib} ||= {};

    # if style attribute value is a hash, just extend/modify the existing value
    if ($attrib eq 'style' && ref $value eq 'HASH') {
      $self->{'_attributes'}{$attrib}{$_} = $value->{$_} for keys %$value;
      return;
    }

    # if class attribute value is an array, join it with a space first since that array can contain space seperated strings
    $value = join ' ', @$value if $attrib eq 'class' && ref $value eq 'ARRAY';

    my $delimiter = {'class' => qr/\s+/, 'style' => qr/\s*;\s*/};
    for (split $delimiter->{$attrib}, $value) {
      my ($key, $val) = $attrib eq 'style' ? split /\s*:\s*/, $_ : ($_, 1);
      $self->{'_attributes'}{$attrib}{$key} = $val if $key;
    }
  }
  else {
    ($value, my $needs_encoding) = ref $value eq 'ARRAY' ? @$value : ($value);
    $self->{'_attributes'}{$attrib} = $needs_encoding ? $self->encode_htmlentities($value) : $value;
  }
}

sub set_attributes {
  ## Sets multiple attributes to the element
  ## @param HashRef {$attrib1 => $value1, $attrib2 => [$value2, $needs_encoding], 'class' => \@classes ...}
  my ($self, $attribs) = @_;
  $self->set_attribute($_, $attribs->{$_}) for keys %$attribs;
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
  ## @param innerHTML string (or ArrayRef containing both arguments)
  ## @param flag to tell whether or not to parse the HTML - off (no parsing) by default.
  ## @return final HTML string
  ## @exception HTMLParsingException if there is some error in parsing the HTML
  my ($self, $html, $do_parse) = @_;
  ($html, $do_parse) = @$html if ref $html eq 'ARRAY';
  if (defined $html) {
    $self->remove_children;
    if ($do_parse) {
      my $error_message = '';
      $self->append_child($_) for @{$self->_parse_HTML_to_nodes($html, \$error_message)};
      throw exception('DOMException::HTMLParsingException', $error_message) if $error_message;
    }
    else {
      $self->{'_text'} = "$html";
    }
  }
  return $self->{'_text'} if $self->{'_text'} ne '';
  $html  = '';
  $html .= $_->node_type eq $self->TEXT_NODE ? $_->text : $_->outer_HTML for @{$self->{'_child_nodes'}};
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
  $text .= $_->text for @{$self->get_nodes_by_node_type($self->TEXT_NODE)};
  return $text;
}

sub outer_HTML {
  ## Returns actuall HTML represented by the node
  ## @return HTML string
  my $self = shift;

  my $tag         = $self->node_name;
  my $attributes  = join '', map {sprintf(' %s="%s"', $_, $self->get_attribute($_))} keys %{$self->{'_attributes'}};
  return $self->can_have_child ? sprintf(q(<%s%s>%s</%1$s>), $tag, $attributes, $self->inner_HTML) : qq(<$tag$attributes />);
}

sub append_HTML {
  ## Appends an HTML string to the existing inner_HTML
  ## @param HTML string
  ## @param Flag to tell whether to parse the html to nodes or not
  ##  - false: if existing inner_HTML is in form of Nodes, it will be converted to string HTML before appending the new HTML to it (default)
  ##  - true:  parses the HTML string to Nodes and append then as child nodes (this will ignore existing inner_HTML if it's unparsed string)
  ## @return Boolean true unless exception
  ## @exception HTMLParsingException if there is some error in parsing the HTML
  my ($self, $html, $do_parse) = @_;
  if ($do_parse) {
    $self->{'_text'}  = '';
    my $error_message = '';
    $self->append_child($_) for @{$self->_parse_HTML_to_nodes($html, \$error_message)};
    throw exception('DOMException::HTMLParsingException', $error_message) if $error_message;
  }
  else {
    $self->inner_HTML(sprintf '%s%s', $self->inner_HTML, $html);
  }
  return 1;
}

sub _parse_HTML_to_nodes {
  ## private method used in &inner_HTML
  ## function to parse HTML from a string to tree structure
  my ($self, $html, $error_ref) = @_;

  my $nodes = [];
  my $error_message;
  my @raw_nodes;
  my @tags;
  my @lifo;

  my $current_node;

  while ($html =~ /(<(\/?)(\w+)((\s+\w+(\s*=\s*(?:".*?"|'.*?'|[^'">\s]+))?)+\s*|\s*)(\/?)>)/g) {
    my $tag = {
      'string'  => $1,
      'start'   => $-[1],
      'end'     => $+[1],
      'name'    => lc $3,
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
      my $node = $self->dom->create_text_node($self->decode_htmlentities($_->{'text'}));
      $current_node ? $current_node->append_child($node) : push @$nodes, $node;
    }
    elsif ($_->{'type'} eq 'end_tag') {
      my $expected    = pop @lifo;
      $current_node   = $current_node->parent_node, next if $_->{'name'} eq $expected;
      $$error_ref     = sprintf('Unexpected closing tag found - %s as in %s, expected %s tag.', $_->{'name'}, $_->{'string'}, $expected || 'no');
      return $nodes; #return the parsed ones
    }
    else {
      my $node;
      try {
        $node = $self->dom->create_element($_->{'name'}, $_->{'attr'});
      }
      catch {
        $$error_ref = $_->message(1);
      };
      return $nodes if !$node; #return the parsed ones
      $current_node ? $current_node->append_child($node) : push @$nodes, $node;
      push @lifo, $_->{'name'} and $current_node = $node if $_->{'type'} eq 'start_tag';
    }
  }
  
  return $nodes;
}

1;
