=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::P_feature;

### Draws protein features on Transcript/ProteinSummary

use strict;

use base  qw(EnsEMBL::Draw::GlyphSet);

sub colour_key { return $_[1]->analysis->logic_name; }

sub _init {
  my $self    = shift;
  my $protein = $self->{'container'};
  
  return unless $protein->dbID;
  
  my $caption   = $self->my_config('caption');
  my $h         = $self->my_config('height') || 4;
  my $y         = 0;
  my $colourmap = $self->{'config'}->colourmap;
  
  foreach my $logic_name (@{$self->my_config('logic_names') || []}) {
    my $colour;
    
    foreach my $pf (@{$protein->get_all_ProteinFeatures($logic_name)}) {
      my $x = $pf->start;
      my $w = $pf->end - $x;
      
      $self->push($self->Rect({
        x      => $x,
        y      => $y,
        width  => $w,
        height => $h,
        title  => "$caption; Position: " . $pf->start . '-' . $pf->end,
        colour => $colour ||= $self->get_colour($pf),
      }));
    }
    
    $y += $h + 2; ## slip down a line for subsequent analyses
  }
}

1;
