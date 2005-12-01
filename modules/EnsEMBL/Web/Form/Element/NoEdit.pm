package EnsEMBL::Web::Form::Element::NoEdit;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_ );
}

sub render { return '<p>'.$_[0]->value.'</p>'; }

1;
