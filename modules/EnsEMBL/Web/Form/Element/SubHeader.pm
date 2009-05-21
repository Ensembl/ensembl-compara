package EnsEMBL::Web::Form::Element::SubHeader;

use strict;
use base qw( EnsEMBL::Web::Form::Element );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_, 'layout' => 'spanning' );
}

sub render { return '<tr><td colspan="2" style="text-align:left"><h3>'.$_[0]->value.'</h3></td></tr>'; }

1;
