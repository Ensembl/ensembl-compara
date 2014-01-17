=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::GlyphSet::variation_legend;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self     = shift;
  my $features = $self->{'legend'}{[split '::', ref $self]->[-1]};
  
  return unless $features;

  my %labels = map { $_->SO_term => [ $_->rank, $_->label ] } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  
  $self->init_legend(3);

  foreach (sort { $labels{$a}[0] <=> $labels{$b}[0] } keys %$features) {
    $self->add_to_legend({
      legend => $labels{$_}[1],
      colour => $features->{$_},
    });
  }
}

1;
