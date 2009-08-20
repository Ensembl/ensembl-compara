package EnsEMBL::Web::Form::Element::NonNegInt;

use strict;
use base qw( EnsEMBL::Web::Form::Element::String );

sub new { my $class = shift; return $class->SUPER::new( @_, 'style' => 'short' ); }

sub _is_valid { return $_[0]->value =~ /^[+-]?\d+$/ &&  $_[0]->value > 0; }

sub _class { return '_nonnegint' . ($_[0]->max ? ' max_' . $_[0]->max : ''); }

sub required_string { return $_[0]->SUPER::required_string . ($_[0]->max ? sprintf ' (Maximum of %d)', $_[0]->max : ''); }
1;
