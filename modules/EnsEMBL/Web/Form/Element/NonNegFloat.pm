package EnsEMBL::Web::Form::Element::NonNegFloat;

use strict;

use base qw(EnsEMBL::Web::Form::Element::NonNegInt);

use constant {
  VALIDATION_CLASS =>  '_nonnegfloat',
};

1;