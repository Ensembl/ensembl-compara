package EnsEMBL::Web::Form::Element::Information;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_, 'layout' => 'spanning' );
}

sub render {
  my $self = shift;
  my $class = $self->style eq 'spaced' ? ' class="space-below"' : '';
  return sprintf '
    <p%s>%s</p>
  ', $class, $self->value;
}

1;
