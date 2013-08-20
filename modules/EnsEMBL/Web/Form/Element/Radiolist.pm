package EnsEMBL::Web::Form::Element::Radiolist;

use strict;

use base qw(EnsEMBL::Web::Form::Element::Checklist);

sub _is_multiple {
  ## @overrides
  return 0;
}

1;