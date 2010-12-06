package EnsEMBL::Web::Form::Element::Email;

use strict;

use base qw(EnsEMBL::Web::Form::Element::String);

use constant {
  VALIDATION_CLASS =>  '_email',
};

1;