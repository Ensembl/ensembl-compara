package EnsEMBL::Web::Form::Element::SubHeader;

use EnsEMBL::Web::Form::Element;
our @ISA = qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_, 'layout' => 'spanning' );
}

# TODO: make sure "h3" class is implemented in css
sub render { return '<dl><dt class="wide h3"><strong>'.$_[0]->value.'</strong></dt></dl>'; }

1;
