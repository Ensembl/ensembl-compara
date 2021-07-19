=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Tools::ExoticSorts;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(id_sort);

sub _id_sort_inner {
  my ($exploded,$a,$b) = @_;

  my ($ae,$be) = ($exploded->{$a},$exploded->{$b});
  my $val = 0;
  for(my $i=0;$ae->[$i] or $be->[$i];$i++) {
    return -1 unless defined $ae->[$i];
    return  1 unless defined $be->[$i];
    my $c = $ae->[$i][0] <=> $be->[$i][0];
    return $c if $c;
    $c = $ae->[$i][1] cmp $be->[$i][1] if $ae->[$i][0] == 2;
    $c = $ae->[$i][1] <=> $be->[$i][1] if $ae->[$i][0] == 1;
    return $c if $c;
  }
  return 0;
}

# Tries to sort IDs into natural order when they implicitly contain
#   sections delimited either by punctuation or transition from letters
#   to numbers and vice versa (for example if A3B27 should sort before
#   A11B7 because 3<11). This is the case for many kinds of ID but not
#   those which are hash/hex/base-n style. Punctuation is taken as being
#   equivalent; numbered sections sorted numberically, alphabetic
#   alphabetically.
sub id_sort {
  my ($in) = @_;

  my %exploded;
  foreach my $value (@$in) {
    my @exp;
    local $_ = $value;
    while($_) {
      push @exp,[2,lc $1] if s/^([A-Za-z]+)//;
      push @exp,[1,lc $1] if s/^([0-9]+)//;
      push @exp,[0,'-'] if s/^[^A-Za-z0-9]//;
    }
    $exploded{$value} = \@exp;
  }
  return [ sort { _id_sort_inner(\%exploded,$a,$b) } @$in ];
}

1;

