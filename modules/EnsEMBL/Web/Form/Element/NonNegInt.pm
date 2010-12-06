package EnsEMBL::Web::Form::Element::NonNegInt;

use strict;

use base qw(EnsEMBL::Web::Form::Element::String);

use constant {
  VALIDATION_CLASS =>  '_nonnegint',
};

1;