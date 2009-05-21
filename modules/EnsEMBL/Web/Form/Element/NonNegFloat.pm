package EnsEMBL::Web::Form::Element::NonNegFloat;

use strict;
use base qw( EnsEMBL::Web::Form::Element::String );

sub new { my $class = shift; return $class->SUPER::new( @_, 'style' => 'short' ); }

sub _is_valid { return $_[0]->value =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/ && $_[0]->value > 0; }

sub _class { return '_nonnegfloat'; }
1;
