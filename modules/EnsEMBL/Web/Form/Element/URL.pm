package EnsEMBL::Web::Form::Element::URL;

use strict;
use base qw( EnsEMBL::Web::Form::Element::String );

sub _is_valid { return $_[0]->value =~ /^https?:\/\/\w.*$/; }

sub _class { return '_url'; }
1;
