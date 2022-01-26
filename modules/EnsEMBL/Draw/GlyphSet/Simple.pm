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

package EnsEMBL::Draw::GlyphSet::Simple;

### Parent class of many Ensembl tracks that draw features as simple coloured blocks

use strict;

use EnsEMBL::Draw::Style::Feature;

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
  $height               = $self->{'extras'}{'height'} if $self->{'extras'} && $self->{'extras'}{'height'};
  $self->{'my_config'}->set('height', $height); 

  ## OK, done!
  return $features; 
}

sub render_labels {
  my $self = shift;
  $self->{'my_config'}->set('show_labels', 1);
  $self->render_normal;
}

sub render_normal {
  my $self = shift;

  my $data = $self->get_data;
  if (scalar @{$data->[0]{'features'}||[]}) {
    my $config = $self->track_style_config;
    my $style  = EnsEMBL::Draw::Style::Feature->new($config, $data);
    $self->push($style->create_glyphs);
  }
  else {
    $self->no_features;
  }
}

sub get_colours {
  my ($self, $f) = @_;
  my ($colour_key, $flag) = $f->{'colour_key'};

  if (!$self->{'feature_colours'}{$colour_key}) {
    $self->{'feature_colours'}{$colour_key} = {
      key     => $colour_key,
      feature => $self->my_colour($colour_key, $flag),
      label   => $self->my_colour($colour_key, 'label'),
      part    => $self->my_colour($colour_key, 'style')
    };
  }
 
  return $self->{'feature_colours'}{$colour_key};
}

sub ok_feature {
### Check if this feature is OK to display
### @param feature - some kind of feature object
### @return array - start and end of feature
  my ($self, $f) = @_;

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

  return ($start, $end);
}

1;
