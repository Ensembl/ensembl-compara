package EnsEMBL::Web::Text::Feature::GTF;
use strict;

use base qw(EnsEMBL::Web::Text::Feature::GFF);

sub new {
  my( $class, $hash_ref ) = @_;
  my $extra = { '_type' => ['transcript']};
  my @T = split /;\s*/, $hash_ref->[16];
  foreach (@T) {
    my($k,$v)= split /=/, $_, 2;
    $k =~ s/^\s+//;
    $k =~ s/\s+$//;
    $v =~ s/^\s+//;
    $v =~ s/\s+$//;
    $v =~ s/^"([^"]+)"$/$1/;
    push @{$extra->{$k}},$v;
  }
  return bless {
    '__raw__'   => $hash_ref,
    '__extra__' => $extra
  },
  $_[0];
}

1;
