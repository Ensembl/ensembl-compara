package EnsEMBL::Web::Form::Element::Button;
use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Form::Element);

sub new { my $class = shift; return $class->SUPER::new(@_); }

sub render { 
  my $self = shift; 
  return sprintf '<input type="button" name="%s" value="%s" %s />',  encode_entities($self->name) || 'submit', encode_entities($self->value), $self->class_attrib || 'class="submit"';
}

1;
