=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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
package EnsEMBL::Web::Query::GlyphSet::RFUnderlying;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Query::Generic::GlyphSet);

our $VERSION = 1;

sub precache {
  return {
  };
}

sub fixup {
  my ($self) = @_;

  $self->fixup_regulatory_feature('feature','species','type');
  $self->fixup_epigenome('epigenome','species','type');
  $self->fixup_loci('locus','feature');
  $self->SUPER::fixup();
}

sub get {
  my ($self,$args) = @_;

  my $out = $args->{'feature'}->get_underlying_structure($args->{'epigenome'});
  return [ map { +{ locus => $_ } } @{$out} ];
}
1;
