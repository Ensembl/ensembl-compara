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

package EnsEMBL::Draw::GlyphSet::Simple;

### Parent class of many Ensembl tracks that draw features as simple coloured blocks

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub init {
  my $self = shift;
  
  my $strand      = $self->strand;
  my $strand_flag = $self->my_config('strand');
  
  ## If only displaying on one strand skip IF not on right strand....
  return if $strand_flag eq 'r' && $strand != -1;
  return if $strand_flag eq 'f' && $strand != 1;
  
  my $slice        = $self->{'container'};
  my $slice_length = $slice->length;
  my $max_length   = $self->my_config('threshold') || 200000000;
  
  return $self->errorTrack($self->my_config('caption'). " only displayed for less than $max_length Kb.") if $slice_length > $max_length * 1010;
  
  my $features = $self->features || [];
  
  ## No features show "empty track line" if option set
  if ($features eq 'too_many') {
    $self->too_many_features;
    return [];
  }
  elsif (!scalar(@$features)) {
    $self->no_features;
    return [];
  }
  
  my $depth = $self->depth;
  $depth    = 1e3 unless defined $depth;
  $self->{'my_config'}->set('depth', $depth); 

  my ($font, $fontsize) = $self->get_font_details($self->my_config('font') || 'innertext');
  my $height            = $self->my_config('height') || [$self->get_text_width(0, 'X', '', font => $font, ptsize => $fontsize)]->[3] + 2;
  $height               = 4 if $depth > 0 && $self->get_parameter('squishable_features') eq 'yes' && $self->my_config('squish');
  $height               = $self->{'extras'}{'height'} if $self->{'extras'} && $self->{'extras'}{'height'};
  $self->{'my_config'}->set('height', $height); 

  return @$features; 
}


1;
