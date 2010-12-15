package EnsEMBL::Web::Form::Element::Radiolist;

use strict;

use base qw(EnsEMBL::Web::Form::Element::Checklist);

use constant {
  _IS_MULTIPLE  => 0,
  _ELEMENT_TYPE => 'inputradio'
};

1;