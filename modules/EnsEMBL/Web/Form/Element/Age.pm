package EnsEMBL::Web::Form::Element::Age;
use strict;
use base qw( EnsEMBL::Web::Form::Element::String );

sub new {
  my $class = shift;
  return $class->SUPER::new( @_, 'style' => 'short' );
}

sub _is_valid {
  return $_[0]->value =~ /^\d+$/ && $_[0]->value > 0 && $_[0]->value <=150;
}

sub _class {
  return '_age';
}
1;
