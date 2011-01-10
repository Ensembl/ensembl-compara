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

1;

