package EnsEMBL::Web::Form::Element::URL;

use EnsEMBL::Web::Form::Element::String;
our @ISA = qw( EnsEMBL::Web::Form::Element::String );

sub _is_valid { return $_[0]->value =~ /^https?:\/\/\w.*$/; }

1;
