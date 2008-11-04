package EnsEMBL::Web::Form::Element::Information;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_, 'layout' => 'spanning' );
}

sub render {
  my $self = shift;
  return sprintf '
    <dl><dt class="wide">%s</dt></dl>
  ', $self->value;
}

1;
