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

package EnsEMBL::Draw::GlyphSet::TSE_transcript;

### Module for Transcript Supporting Evidence tracks - see
### EnsEMBL::Web::Component::Transcript::SupportingEvidence 

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_transcript);

sub render_normal {
## Default (and currently only) rendering style for this track, which takes
## the form of exon blocks joined by horizontal lines

  my $self              = shift;
  my $config            = $self->{'config'};
  my $h                 = 8; # Increasing this increases glyph height
  my $pix_per_bp        = $config->transform_object->scalex;
  my $length            = $config->container_width;
  my $trans_obj         = $self->cache('trans_object');
  my $coding_start      = $trans_obj->{'coding_start'};
  my $coding_end        = $trans_obj->{'coding_end'};
  my $transcript        = $trans_obj->{'transcript'};
  my $colour_key        = $self->colour_key($config->core_object('gene')->Obj, $transcript); # need both gene and transcript to get the colour
  my $colour            = $self->my_colour($colour_key);
  my $strand            = $transcript->strand;
  my $tsi               = $transcript->stable_id;
  my @introns_and_exons = @{$trans_obj->{'introns_and_exons'}};
  my $tags;
  
  foreach my $obj (@introns_and_exons) {
    #i f we're working with an exon then draw a box
    if ($obj->[2]) {
      my $exon_start = $obj->[0];
      my $exon_end   = $obj->[1];

      # set the exon boundries to the image boundries in case anything odd has happened
      $exon_start = 1       if $exon_start < 1;
      $exon_end   = $length if $exon_end > $length;

      my $t_url = $self->_url({
        type   => 'Transcript',
        action => 'Evidence',
        t      => $tsi,
        exon   => $obj->[2]->stable_id
      });

      my $col1 = $self->my_colour('noncoding_join', 'join');
      my $col2 = $self->my_colour('coding_join',    'join');
      
      my $glyph = $self->Rect({
        bordercolour => $colour,
        absolutey    => 1,
        title        => $obj->[2]->stable_id,
        href         => $t_url
      });
      
      my ($glyph2, $tag);
      
      # draw and tag completely non-coding exons
      if (($exon_end < $coding_start) || ($exon_start > $coding_end)) {
        $glyph->{'x'}      = $exon_start;
        $glyph->{'y'}      = 0.5 * $h;
        $glyph->{'width'}  = $exon_end - $exon_start;
        $glyph->{'height'} = $h;
        
        $tag = "$exon_end:$exon_start";
        
        push @$tags, [ "X:$tag", $col1 ];
        
        $self->join_tag($glyph, "X:$tag", 0,  0, $col1, 'fill', -99);
        $self->join_tag($glyph, "X:$tag", 1,  0, $col1, 'fill', -99);
        $self->push($glyph);
      } elsif (($exon_start >= $coding_start) && ($exon_end <= $coding_end)) {
        # draw and tag completely coding exons
        $glyph->{'x'}      = $exon_start;
        $glyph->{'y'}      = 0;
        $glyph->{'width'}  = $exon_end - $exon_start;
        $glyph->{'height'} = 2 * $h;
        $glyph->{'colour'} = $colour;
        
        $tag = "$exon_end:$exon_start";
        
        push @$tags, [ "X:$tag", $col2 ];
        
        $self->join_tag($glyph, "X:$tag", 0,  0, $col2, 'fill', -99);
        $self->join_tag($glyph, "X:$tag", 1,  0, $col2, 'fill', -99);
        $self->push($glyph);
      } elsif (($exon_start < $coding_start) && ($exon_end > $coding_start)) {
        $glyph2 = $self->Rect({
          bordercolour => $glyph->{'bordercolour'},
          absolutey    => $glyph->{'absolutey'},
          title        => $glyph->{'title'},
          href         => $glyph->{'href'}
        });
        
        # draw and tag partially coding transcripts on left hand
        
        # non coding part
        $glyph2->{'x'}      = $exon_start;
        $glyph2->{'y'}      = 0.5 * $h;
        $glyph2->{'width'}  = $coding_start - $exon_start;
        $glyph2->{'height'} = $h;
        
        $tag = "$coding_start:$exon_start";
        
        push @$tags, [ "X:$tag", $col1 ];
        
        $self->join_tag($glyph2, "X:$tag", 0,  0, $col1, 'fill', -99);
        $self->join_tag($glyph2, "X:$tag", 1,  0, $col1, 'fill', -99);
        $self->push($glyph2);
        
        #coding part
        my $glyph3 = $self->Rect({
          bordercolour => $glyph->{'bordercolour'},
          absolutey    => $glyph->{'absolutey'},
          title        => $glyph->{'title'},
          href         => $glyph->{'href'}
        });
        
        my $width = ($exon_end > $coding_end) ? $coding_end - $coding_start : $exon_end - $coding_start;
        my $y_pos = ($exon_end > $coding_end) ? $coding_end : $exon_end;
        
        $glyph3->{'x'}      = $coding_start;
        $glyph3->{'y'}      = 0;
        $glyph3->{'width'}  = $width;
        $glyph3->{'height'} = 2 * $h;
        $glyph3->{'colour'} = $colour;
        
        $tag = "$y_pos:$coding_start";
        
        push @$tags, [ "X:$tag", $col2 ];
        
        $self->join_tag($glyph3, "X:$tag", 0,  0, $col2, 'fill', -99);
        $self->join_tag($glyph3, "X:$tag", 1,  0, $col2, 'fill', -99);
        $self->push($glyph3);
        
        # draw non-coding part if there's one of these as well
        if ($exon_end > $coding_end) {
          my $glyph4 = $self->Rect({
            bordercolour => $glyph->{'bordercolour'},
            absolutey    => $glyph->{'absolutey'},
            title        => $glyph->{'title'},
            href         => $glyph->{'href'},
          });
          
          $glyph4->{'x'}      = $coding_end;
          $glyph4->{'y'}      = 0.5 * $h;
          $glyph4->{'width'}  = $exon_end - $coding_end;
          $glyph4->{'height'} = $h;
          
          $tag = "$exon_end:$coding_end";
          
          push @$tags, [ "X:$tag", $col1 ];
          
          $self->join_tag($glyph4, "X:$tag", 0,  0, $col1, 'fill', -99);
          $self->join_tag($glyph4, "X:$tag", 1,  0, $col1, 'fill', -99);
          $self->push($glyph4);
        }
      } elsif (($exon_end > $coding_end) && ($exon_start < $coding_end)) {
        # draw and tag partially coding transcripts on the right hand
        $glyph2 = $self->Rect({
          bordercolour => $glyph->{'bordercolour'},
          absolutey    => $glyph->{'absolutey'},
          title        => $glyph->{'title'},
          href         => $glyph->{'href'}
        });
        
        # coding part
        $glyph2->{'x'}      = $exon_start;
        $glyph2->{'y'}      = 0;
        $glyph2->{'width'}  = $coding_end - $exon_start;
        $glyph2->{'height'} = 2 * $h;
        $glyph2->{'colour'} = $colour;
        
        $tag = "$coding_end:$exon_start";
        
        push @$tags, [ "X:$tag", $col2 ];
        
        $self->join_tag($glyph2, "X:$tag", 0,  0, $col2, 'fill', -99);
        $self->join_tag($glyph2, "X:$tag", 1,  0, $col2, 'fill', -99);
        $self->push($glyph2);
        
        # non coding part
        $glyph->{'x'}      = $coding_end;
        $glyph->{'y'}      = 0.5 * $h;
        $glyph->{'width'}  = $exon_end - $coding_end;
        $glyph->{'height'} = $h;
        
        $tag = "$exon_end:$coding_end";
        
        push @$tags, [ "X:$tag", $col1 ];
        
        $self->join_tag($glyph, "X:$tag", 0,  0, $col1, 'fill', -99);
        $self->join_tag($glyph, "X:$tag", 1,  0, $col1, 'fill', -99);
        $self->push($glyph);
      }
      
      $config->cache('vertical_tags', $tags);
    } else {
      # otherwise draw a line to represent the intron context
      my $glyph = $self->Line({
        x         => $obj->[0] + 1 / $pix_per_bp,
        y         => $h,
        h         => 1,
        width     => $obj->[1] - $obj->[0] - 2 / $pix_per_bp,
        colour    => $colour,
        absolutey => 1,
      });
      
      $self->push($glyph);
    }
  }

  # draw a direction arrow
  $self->push($self->Line({
    x         => 0,
    y         => -4,
    width     => $length,
    height    => 0,
    absolutey => 1,
    colour    => $colour
  }));
  
  if ($strand == 1) {
    $self->push($self->Poly({
      colour    => $colour,
      absolutey => 1,
      points    => [
        $length - 4/$pix_per_bp, -2,
        $length                , -4,
        $length - 4/$pix_per_bp, -6
      ]
    }));
  } else {
    $self->push($self->Poly({
      colour    => $colour,
      absolutey => 1,
      points    => [
        4/$pix_per_bp, -6,
        0            , -4,
        4/$pix_per_bp, -2
      ]
    }));
  }
}

1;
