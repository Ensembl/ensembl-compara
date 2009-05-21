package EnsEMBL::Web::Form::Element::Email;

use strict;
use base qw( EnsEMBL::Web::Form::Element::String );

sub _is_valid { return $_[0]->value =~ /^[^@]+@[^@.:]+[:.][^@]+$/; }

sub _class { return '_email'; }
1;
