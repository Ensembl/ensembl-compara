=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Text::Feature::GTF;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature::GFF);

sub new {
  my( $class, $hash_ref ) = @_;
  my $extra = { '_type' => ['transcript']};
  my @T = split /;\s*/, $hash_ref->[16];
  foreach (@T) {
    $_ =~ s/^\s+//;
    $_ =~ s/\s+$//;
    my($k,$v)= split /\s+/, $_, 2;
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
