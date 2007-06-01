package EnsEMBL::Web::Form::Element::NoEdit;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_ );
}

sub render { 
  my $value = $_[0]->value || '&nbsp;';
  return "<p>$value</p>"; 
}

1;
