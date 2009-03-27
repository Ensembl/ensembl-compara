package EnsEMBL::Web::Form::Element::Header;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_, 'layout' => 'spanning' );
}

sub render { return '<tr><td colspan="2" style="text-align:left"><h2>'.$_[0]->value.'</h2></td></tr>'; }

1;
