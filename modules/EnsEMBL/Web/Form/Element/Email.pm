package EnsEMBL::Web::Form::Element::Email;

use EnsEMBL::Web::Form::Element::String;
our @ISA = qw( EnsEMBL::Web::Form::Element::String );

sub _is_valid { return $_[0]->value =~ /^[^@]+@[^@.:]+[:.][^@]+$/; }

sub _class { return '_email'; }
1;
