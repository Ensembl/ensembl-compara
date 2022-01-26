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

package EnsEMBL::Draw::GlyphSet::Vannotation_status;

### Vega annotation status on vertical ideograms

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

sub _init {
  my $self = shift;

  ## get NoAnnotation features from db
  my $chr = $self->{'container'}->{'chr'};
  my $slice_adapt   = $self->{'container'}->{'sa'};  
  my $chr_slice = $slice_adapt->fetch_by_region('chromosome', $chr);
  my $bp_per_pixel = ($chr_slice->length)/450;

  ## bottom align each chromosome
  my $c_w = $self->get_parameter('container_width');
  my $chr_length = $chr_slice->length || 1;
  my $v_offset   = $c_w - $chr_length;

  my @features;
  push @features,
    @{ $chr_slice->get_all_MiscFeatures('NoAnnotation') };

  ## get configuration
  my $tag_pos = $self->my_config('tag_pos');
  my %colour = (
    'NoAnnotation'      => 'gray75',
  );


  ## draw the glyphs
 F:
  foreach my $f (@features) {
    my ($ms) = @{ $f->get_all_MiscSets('NoAnnotation') };

    #set length of feature to the equivalent of 1 pixel if it's less than 1 pixel
    my $f_length = $f->end - $f->start;
    my $width = ($f_length > $bp_per_pixel) ? $f_length : $bp_per_pixel;
    #hack for zfish karyotype display - don't show small bands
#    next F if ( ($bp_per_pixel/$f_length) > 2);

#    warn "drawing x at ",$f->start + $v_offset;
#    warn "drawing y at $width";

    my $glyph = $self->Rect({
      'x'      => $f->start + $v_offset ,
      'y'      => 0,
      'width'  => $width,
      'height' => 1,
      'colour' => $colour{$ms->code},
    });
    $self->push($glyph);

    ## tagging
    $self->join_tag($glyph, $f->end."-".$f->start, $tag_pos, $tag_pos, $colour{$ms->code}, 'fill', -10);
    $self->join_tag($glyph, $f->end."-".$f->start, 1-$tag_pos, $tag_pos, $colour{$ms->code}, 'fill', -10);
  }
}

1;
