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

package Bio::EnsEMBL::GlyphSet::gene_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self     = shift;
  my $features = $self->{'legend'}{[split '::', ref $self]->[-1]};
  
  return unless $features;

  $self->init_legend(2);
  
  foreach my $type (sort { $features->{$a}{'priority'} <=> $features->{$b}{'priority'} } keys %$features) {
    my $join    = $type eq 'joins';
    my @colours = $join ? map { $_, $features->{$type}{'legend'}{$_} } sort keys %{$features->{$type}{'legend'}} : @{$features->{$type}{'legend'}};
  
    $self->newline(1);
    
    while (my ($legend, $colour) = splice @colours, 0, 2) {
      $self->add_to_legend({
        legend => $legend,
        colour => $colour,
        style  => $type eq 'joins' ? 'line' : 'box',
      });
    }
  }
}

1;
        
