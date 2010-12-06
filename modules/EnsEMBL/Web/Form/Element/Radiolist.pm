package EnsEMBL::Web::Form::Element::Radiolist;

use strict;

use base qw(EnsEMBL::Web::Form::Element::Checklist);

sub __multiple {
  ## @override
  return 0;
}

sub __input {
  ## @overrides
  return 'inputradio';
}

1;