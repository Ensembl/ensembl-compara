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

package EnsEMBL::Draw::GlyphSet::fg_multi_wiggle_legend;

### Legend for regulatory build tracks

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::legend);

sub _init {
  my $self     = shift;
  my $features = $self->{'legend'}{[split '::', ref $self]->[-1]}{'colours'};
  
  return unless $features;
 
  $self->init_legend(4);
 
  my $empty = 1;
  my $items = []; 
  
  foreach (sort keys %$features) {  
    $self->add_to_legend({
      legend => $_,
      colour => $features->{$_} || 'black',
    });
    
    $empty = 0;
  }
  
  $self->errorTrack('No Cell/Tissue regulation data in this panel') if $empty;
}

1;
