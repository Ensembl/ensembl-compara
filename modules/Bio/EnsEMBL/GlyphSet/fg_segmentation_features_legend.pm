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

package Bio::EnsEMBL::GlyphSet::fg_segmentation_features_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub _init {
  my $self = shift;

  return unless $self->{'legend'}{[split '::', ref $self]->[-1]};
  
  my %features = %{$self->my_config('colours')};
  
  return unless %features;

  $self->init_legend(2);

  my $empty = 1;
  
  foreach (sort keys %features) {
    my $legend = $self->my_colour($_, 'text'); 
    
    next if $legend =~ /unknown/i; 
    
    $self->add_to_legend({
      legend => $legend,
      colour => $self->my_colour($_),
    });

    $empty = 0;
  }
  
  $self->errorTrack('No Segmentation Features in this panel') if $empty;
}

1;
