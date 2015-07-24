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

package EnsEMBL::Draw::GlyphSet::Alignment;

### Parent class of many Ensembl tracks that draw features as simple coloured blocks

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub colour_key { return $_[0]->my_config('colour_key') || $_[0]->my_config('sub_type'); }

## Renderers which tweak the standard track style

sub render_as_alignment_label {
  my $self = shift;
  $self->{'my_config'}->set('show_labels', 1);
  $self->render_as_alignment_nolabel;
}

sub render_half_height { 
  my $self = shift;
  my $height = $self->my_config('height') / 2 || 4;
  $self->{'my_config'}->set('height', $height);
  $self->{'my_config'}->set('depth', 20);
  
  $self->render_as_alignment_nolabel;
}                                                           

sub render_stack { 
  my $self = shift;
  ## Show as a deep stack of densely packed features
  $self->{'my_config'}->set('height', 1);
  $self->{'my_config'}->set('vspacing', 0);
  $self->{'my_config'}->set('depth', 40);
  ## Draw joins as 50% transparency, not borders
  $self->{'my_config'}->set('alpha', 0.5);

  $self->render_as_alignment_nolabel;
}

sub render_unlimited {
  my $self = shift;
  ## Show as a very deep stack of densely packed features
  $self->{'my_config'}->set('height', 1);
  $self->{'my_config'}->set('vspacing', 0);
  $self->{'my_config'}->set('depth', 1000);
  ## Draw joins as 50% transparency, not borders
  $self->{'my_config'}->set('alpha', 0.5);

  $self->render_as_alignment_nolabel;
}


1;
