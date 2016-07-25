=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Utils::EqualityComparator;

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT_OK = qw(is_same);

sub is_same {
  ## @function
  my ($a, $b) = @_;

  return 1 if !defined $a && !defined $b; # both undef
  return 0 if !defined $a || !defined $b; # just one of them is undef
  return 1 if "$a" eq "$b";               # same values or same references
  return 0 if !ref $a || !ref $b;         # either of them is a string but isn't same as the other (as compared on previous line)
  return 0 if ref $a ne ref $b;           # object type is not matching

  # both are hash based objects
  if (UNIVERSAL::isa($a, 'HASH')) {
    return 0 unless is_same([ sort keys %$a ], [ sort keys %$b ]);
    return grep !is_same($a->{$_}, $b->{$_}), keys %$a ? 0 : 1;
  }

  # both are array based objects
  if (UNIVERSAL::isa($a, 'ARRAY')) {
    return 0 unless scalar @$a eq scalar @$b;
    return grep !is_same($a->[$_], $b->[$_]), 0..$#$a ? 0 : 1;
  }

  # both are scalar references
  if (UNIVERSAL::isa($a, 'SCALAR')) {
    return $$a eq $$b ? 1 : 0;
  }

  # no idea
  return 0;
}

1;
