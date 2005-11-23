package EnsEMBL::Web::Form::Element::Header;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_, 'spanning' => 'yes' );
}

sub render { return '<h3 class="plain">'.$_[0]->value.'</h3>'; }

1;
