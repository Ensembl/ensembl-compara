package EnsEMBL::Web::Form::Element::Int;

use strict;
use base qw( EnsEMBL::Web::Form::Element::String );

sub new { my $class = shift; return $class->SUPER::new( @_, 'style' => 'short' ); }

sub _is_valid { return $_[0]->value =~ /^[+-]?\d+$/; }

sub _class { return '_int'; }
1;
