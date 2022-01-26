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

package EnsEMBL::Draw::GlyphSet::lrg_band;

### Shows LRG slice

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my $self = shift;

  my $slice  = $self->{'container'}; 
  my $length = $slice->length;
  my $lrg_id = $slice->seq_region_name;
  
  my $strand     =  1;
  my $pix_per_bp = $self->scalex;
  
  my $start = $slice->start;
  my $end   = $slice->end;
  
  my ($fontname, $fontsize) = $self->get_font_details('innertext');
  my $h = [ $self->get_text_width(0, 'X', '', font => $fontname, ptsize => $fontsize) ]->[3];
  
  my $label = $lrg_id;

  $self->push($self->Rect({
    'x'         => $start,
    'y'         => 0,
    'height'    => $h + 4,
    'width'     => $length,
    'title'     => $label,
    'colour'    => 'contigblue1',
    'absolutey' => 1
  }));
  
  my @res = $self->get_text_width(($end - $start + 1) * $pix_per_bp, $label, '', font => $fontname, ptsize => $fontsize);    

  if ($res[0]) {
    $self->push($self->Text({
       x         => ($end + $start - 1 - $res[2]/$pix_per_bp) / 2,
       y         => 1,
       width     => $res[2] / $pix_per_bp,
       textwidth => $res[2],
       font      => $fontname,
       height    => $h,
       ptsize    => $fontsize,
       colour    => 'white',
       text      => $res[0],
       absolutey => 1,
    }));        
  }
}

1;
