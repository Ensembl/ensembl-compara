package EnsEMBL::Web::TextSequence::ClassToStyle::CSS;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::TextSequence::ClassToStyle);

sub convert_class_to_style {
  my ($self,$current_class,$config) = @_;

  return undef unless @$current_class;
  my %class_to_style = %{$self->make_class_to_style_map($config)};
  my %style_hash;
  foreach (sort { $class_to_style{$a}[0] <=> $class_to_style{$b}[0] } @$current_class) {
    my $st = $class_to_style{$_}[1];
    map $style_hash{$_} = $st->{$_}, keys %$st;
  }
  return join ';', map "$_:$style_hash{$_}", keys %style_hash;
}

1;
