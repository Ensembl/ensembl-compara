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

package EnsEMBL::Draw::GlyphSet::text_seq_legend;

### Legend for text sequence views that use Component::TextSequence

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my $self = shift;

  my $config = $self->{'config'};   
  my %legend = %{$config->{'legend'} || {}}; 
  
  return unless %legend;
 
  my ($fontname, $fontsize) = $self->get_font_details('legend');
  
  $fontsize += 0.5;
  
  my $width       = $config->image_width;
  my @res         = $self->get_text_width(0, 'X', '', 'font' => $fontname, 'ptsize' => $fontsize);
  my $th          = $res[3];
  my $pix_per_bp  = $config->transform_object->scalex;
  my $box_width   = 0;
  my $label_width = 0;
  my $columns     = 3;
  my ($x ,$y, $i) = (0, 0, 0);
  my %other_features;
  
  foreach my $type (keys %legend) {
    my $label = $type;
    
    if ($type ne 'variations' && scalar keys %{$legend{$type}} == 1) {
      my ($k) = keys %{$legend{$type}};
      $legend{$type} = $legend{$type}{$k};
    }
    
    if ($legend{$type}{'text'}) {
      my $w = [$self->get_text_width(0, $legend{$type}{'text'}, '', 'font' => $fontname, 'ptsize' => $fontsize)]->[2];
      $box_width = $w if $box_width < $w;
      $other_features{$type} = $legend{$type};
      $label = 'Other features';
    } else {
      foreach (keys %{$legend{$type}}) {
        my $w = [$self->get_text_width(0, $legend{$type}{$_}{'text'}, '', 'font' => $fontname, 'ptsize' => $fontsize)]->[2];
        $box_width = $w if $box_width < $w;
      }
    }
    
    my $label_w = [$self->get_text_width(0, $label, '', 'font' => $fontname, 'ptsize' => $fontsize)]->[2];
    $label_width = $label_w if $label_width < $label_w;
  }
  
  foreach (keys %other_features) {
    $legend{'zzz'}{$_} = $other_features{$_}; # Force them to the bottom
    delete $legend{$_};
  }
  
  $label_width += 20;
  
  foreach my $type (sort { $a cmp $b } keys %legend) {
    $y++ unless $x == 0;
    $x = 0;
    
    if ($label_width) {
      $self->push($self->Text({
        x             => 0,
        y             => $y * ($th + 7) + 2,
        height        => $th,
        valign        => 'center',
        halign        => 'left',
        ptsize        => $fontsize,
        font          => $fontname,
        text          => ucfirst($type eq 'zzz' ? scalar keys %legend == 1 ? 'Features' : 'Other features' : $type),
        absolutey     => 1,
        absolutex     => 1,
        absolutewidth => 1
      }));
    }
    
    foreach (sort { $legend{$type}{$a}{'order'} <=> $legend{$type}{$b}{'order'} || $legend{$type}{$a}{'text'} cmp $legend{$type}{$b}{'text'} } keys %{$legend{$type}}) {
      my ($legend, $bg_colour, $colour) = ($legend{$type}{$_}{'text'}, $legend{$type}{$_}{'default'}, $legend{$type}{$_}{'label'});
      my $pos_x = (($box_width + 20) * $x) + $label_width;
      my $pos_y = $y * ($th + 7) + 2;
      
      $self->push($self->Rect({
        x             => $pos_x - 2,
        y             => $pos_y,
        width         => $box_width + 6,
        height        => $th + 4,
        colour        => $bg_colour,
        absolutey     => 1,
        absolutex     => 1,
        absolutewidth => 1,
        bordercolour  =>  'black'
      }));
      
      $self->push($self->Text({
        x             => $pos_x,
        y             => $pos_y + 2,
        height        => $th,
        valign        => 'center',
        halign        => 'left',
        ptsize        => $fontsize,
        font          => $fontname,
        colour        => $colour || '555555',
        text          => $legend,
        absolutey     => 1,
        absolutex     => 1,
        absolutewidth => 1
      }));
      
      $x++;
      
      if ($x == $columns) {
        $x = 0;
        $y++;
      }
    }
    
    $y++ if ++$i < scalar keys %legend;
  }
}

1;

