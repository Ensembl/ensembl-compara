package EnsEMBL::Web::Form::Element::Information;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_, 'layout' => 'spanning' );
}

sub render {
  my $self = shift;
  $self->add_class('wide');
  return sprintf '
    <dl><dt%s%s>%s</dt></dl>
  ', $self->class_attrib, $self->style_attrib, $self->value;
}

1;
