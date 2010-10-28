package EnsEMBL::Web::Form::Element::Information;

use strict;
use base qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_, 'layout' => 'spanning' );
}

sub render {
  my $self = shift;
  $self->add_class('wide');
  return sprintf '
    <tr><td colspan="2"%s%s>%s</td></tr>
  ', $self->class_attrib, $self->style_attrib, $self->value;
}

1;
