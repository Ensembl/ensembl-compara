package EnsEMBL::Web::DOM::Node::Document;

## Status - Under Development - hr5

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::DOM::Node);

sub node_type {
  ## @overrides
  return shift-DOCUMENT_NODE;
}

sub render {
  ## @overrides
  warn 'Render() for the document Node is not yet supported. Do render() the required child elements';
  return '';
}

sub allowed_child_nodes {
  ## @overrides
  return [ qw(html head title body) ];
}

1;

