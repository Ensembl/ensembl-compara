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

  ## Set track depth (i.e. number of rows of features)  
  my $depth = $self->depth;
  $depth    = 1e3 unless defined $depth;
  $self->{'my_config'}->set('depth', $depth); 

  ## Set track height
  my ($font, $fontsize) = $self->get_font_details($self->my_config('font') || 'innertext');
  my $height            = $self->my_config('height') || [$self->get_text_width(0, 'X', '', font => $font, ptsize => $fontsize)]->[3] + 2;
  $height               = 4 if $depth > 0 && $self->get_parameter('squishable_features') eq 'yes' && $self->my_config('squish');
  $height               = $self->{'extras'}{'height'} if $self->{'extras'} && $self->{'extras'}{'height'};
  $self->{'my_config'}->set('height', $height); 

  ## OK, done!
  return $features; 
}

sub ok_feature {
### Check if this feature is OK to display
### @param feature - some kind of feature object
### The following two parameters are only required if the track
### is optimizable (currently only possible for repeats)
### @param previous_start Integer (optional) - start of previous feature
### @param previous_end Integer (optional) - end of previous feature
### @return array - start and end of feature
  my ($self, $f, $previous_start, $previous_end) = @_;

  my $fstrand = $f->strand || -1;
  my $strand_flag = $self->my_config('strand');

  return 0 if $strand_flag eq 'b' && $self->strand != $fstrand;

  my $start = $f->start;
  my $end   = $f->end;

  my $slice         = $self->{'container'};
  my $slice_length  = $slice->length;
  return 0 if $start > $slice_length || $end < 1; ## Skip if totally outside slice

  $start            = 1             if $start < 1;
  $end              = $slice_length if $end > $slice_length;

  my $optimizable   = $self->my_config('optimizable') && $self->my_config('depth') < 1;
  my $pix_per_bp    = $self->scalex;
  return 0 if $optimizable && ($slice->strand < 0 ? $previous_start - $start < 0.5 / $pix_per_bp : $end - $previous_end < 0.5 / $pix_per_bp);
  
  return ($start, $end);
}

1;
