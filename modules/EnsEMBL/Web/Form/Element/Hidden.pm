package EnsEMBL::Web::Form::Element::Hidden;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Form::Element);

sub render {
  return sprintf
    '<input type="hidden" name="%s" value="%s" id="%s" %s />',
    encode_entities($_[0]->name), encode_entities($_[0]->value), encode_entities($_[0]->id), $_[0]->class_attrib;
}

1;
