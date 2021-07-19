=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::DOM;

### Serves as a factory for creating Nodes in the DOM tree

use strict;

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::DOM::Node::Element::Generic;

use base qw(EnsEMBL::Web::Root);

use constant {
  POSSIBLE_HTML_ELEMENTS => [qw(
      a abbr acronym address area b base bdo big blockquote body br button
      caption cite code col colgroup dd del dfn div dl dt em fieldset form
      frame frameset head h1 h2 h3 h4 h5 h6 hr html i iframe img input ins
      kbd label legend li link map meta noframes noscript object ol optgroup
      option p param pre q samp script select small span strong style sub
      sup table tbody td textarea tfoot th thead title tr tt ul var wbr
  )]
};

sub new {
  ## @constructor
  return bless [
    {}, #used classes
    {}  #mapped classes
  ], shift;
}

sub map_element_class {
  ## Maps an element type with a class
  ## When create_element is called with a given node name, the mapped class is instantiated.
  ## @param Hashref of node_name => element_class
  my ($self, $map) = @_;
  $self->[1]{ lc $_ } = $map->{$_} for keys %$map;
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
  ## Also adds attributes, inner_HTML/inner_text and child nodes
  ## @param Element type
  ## @param HashRef of name value pair for attributes, flags, inner_HTML/inner_text and children with keys:
  ##   - any attribute: value as accepted by Node::set_attribute
  ##   - inner_HTML/inner_text: value as accepted by the methods resp.
  ##   - flags: value as accepted by Node::set_flags
  ##   - children: ref to an array that is accepted by append_children method
  ## @return Element subclass object
  ## @exception DOMException - if node name is not valid
  my ($self, $element_name, $attributes)  = @_;

  if (ref $element_name eq 'HASH') {
    $attributes   = $element_name;
    $element_name = delete $attributes->{'node_name'};
  }

  $element_name = lc $element_name;
  $attributes ||= {};
  
  my $node_class;
  
  # skip 'dynamic_use' of element class if already required once
  unless ($node_class = $self->[0]{$element_name}) {

    $node_class = $self->_get_mapped_element_class($element_name);
    if (!$self->dynamic_use($node_class)) {
      $node_class = undef;
      $_ eq $element_name and $node_class = 'EnsEMBL::Web::DOM::Node::Element::Generic' and last for @{$self->POSSIBLE_HTML_ELEMENTS};
      throw exception('DOMException', "Element with node name '$element_name' can not be created.") unless $node_class;
    }
    $self->[0]{$element_name} = $node_class;
  }

  my $element = $node_class->new($self);
  $element->node_name($element_name) if $node_class eq 'EnsEMBL::Web::DOM::Node::Element::Generic';
  if (exists $attributes->{'flags'}) {
    $element->set_flags(delete $attributes->{'flags'});
  }
  if (exists $attributes->{'inner_HTML'}) {
    $element->inner_HTML(delete $attributes->{'inner_HTML'});
    delete $attributes->{'inner_text'};
  }
  elsif (exists $attributes->{'inner_text'}) {
    $element->inner_text(delete $attributes->{'inner_text'});
  }
  my @children = @{delete $attributes->{'children'} || []};
  $element->set_attributes($attributes) if scalar keys %$attributes;
  $element->append_children(@children)  if scalar @children;
  return $element;
}

sub create_text_node {
  ## Creates a text node
  ## @param Text string
  ## @return Text node object
  my $self = shift;
  my $node_class = 'EnsEMBL::Web::DOM::Node::Text';
  $self->dynamic_use($node_class);
  my $text_node = $node_class->new($self);
  $text_node->text(shift) if @_;
  return $text_node;
}

sub create_comment {
  ## Creates comment
  ## @param comment string
  ## @return Comment object
  my $self = shift;
  my $node_class = 'EnsEMBL::Web::DOM::Node::Comment';
  $self->dynamic_use($node_class);
  my $comment_node = $node_class->new($self);
  $comment_node->comment(shift) if @_;
  return $comment_node;
}

sub _get_mapped_element_class {
  my ($self, $element_name) = @_;
  return $self->[1]{$element_name} if exists $self->[1]{$element_name};
  return 'EnsEMBL::Web::DOM::Node::Element::Input::'.ucfirst $1 if $element_name =~ /^input([a-z]+)$/;
  return 'EnsEMBL::Web::DOM::Node::Element::'.ucfirst $element_name;
}

1;
