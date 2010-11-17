package EnsEMBL::Web::DOM::Node::Document;

use strict;

use base qw(EnsEMBL::Web::DOM::Node);

sub node_type {
  ## @overrides
  return shift->DOCUMENT_NODE;
}

sub render {
  ## @overrides
  warn 'Render() for the document Node is not yet supported. Do render() the required child elements';
  return '';
}

sub _appendable {
  ## @overrides
  my ($self, $child) = @_;
  return
    $child->node_type == $self->ELEMENT_NODE
      &&
      $child->node_name =~ /^(html|head|title|body)$/
    ? 1
    : 0
  ;
}

1;

