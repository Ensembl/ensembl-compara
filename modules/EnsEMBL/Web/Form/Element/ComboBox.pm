package EnsEMBL::Web::Form::Element::ComboBox;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  my %params = @_;
  return $class->SUPER::new( %params, 'render_as' => $params{'select'} ? 'select' : 'radiobutton' );
}

1;
