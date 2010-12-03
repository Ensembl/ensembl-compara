package EnsEMBL::Web::DOM::Node::Element::Fieldset;

use strict;

use base qw(EnsEMBL::Web::DOM::Node::Element);

sub node_name {
  ## @overrides
  return 'fieldset';
}

sub form {
  ## Returns a reference to the form object that contains the input
  return shift->get_ancestor_by_tag_name('form');
}

1;