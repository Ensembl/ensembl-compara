package EnsEMBL::Web::Form::Element::Password;

use strict;
use base qw( EnsEMBL::Web::Form::Element::String );

sub new { my $class = shift; return $class->SUPER::new( @_, 'widget_type' => 'password', 'style' => 'short' ); }

sub _is_valid { return $_[0]->value =~ /^\S{6,16}$/; }

sub _class { return '_password'; }
1;
