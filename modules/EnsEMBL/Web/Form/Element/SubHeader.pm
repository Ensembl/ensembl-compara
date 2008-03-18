package EnsEMBL::Web::Form::Element::SubHeader;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_, 'layout' => 'spanning' );
}

sub render { return '<h4>'.$_[0]->value.'</h4>'; }

1;
