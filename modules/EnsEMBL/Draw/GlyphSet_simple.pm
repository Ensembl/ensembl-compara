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

package EnsEMBL::Draw::GlyphSet_simple;

### Parent class of many Ensembl tracks that draw features as simple coloured blocks

use strict;

use Bio::EnsEMBL::Feature;

use base qw(EnsEMBL::Draw::GlyphSet);

sub features    { return []; } 
sub class       {}
sub render_tag  {}

sub get_colours {
  my ($self, $f) = @_;
  my ($colour_key, $flag) = $self->colour_key($f);
  
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

sub _init {
  my ($self, $no_labels) = @_;
  
  return $self->render_text if $self->{'text_export'};
  
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
    return $self->too_many_features;
  }
  elsif (!scalar(@$features)) {
    return $self->no_features;
  }
  
  my ($font, $fontsize) = $self->get_font_details($self->my_config('font') || 'innertext');
  my $label_overlay     = $self->label_overlay;
  my $bump_width        = $self->my_config('bump_width');
     $bump_width        = 1 unless defined $bump_width;
  my $max_length_nav    = $self->my_config('navigation_threshold') || 15000000;
  my $navigation        = $self->my_config('navigation')           || 'on';
     $navigation        = $navigation eq 'on' && $slice_length <= $max_length_nav * 1010;
  my $pix_per_bp        = $self->scalex;
  my $depth             = $self->depth;
     $depth             = 1e5 unless defined $depth;
  my $previous_start    = $slice_length + 1e9;
  my $previous_end      = -1e9;
  my $image_end         = $self->get_parameter('image_end');
  my $optimizable       = $self->my_config('optimizable') && $depth < 1 ; # at the moment can only optimize repeats
  my $height            = $self->my_config('height') || [$self->get_text_width(0, 'X', '', font => $font, ptsize => $fontsize)]->[3] + 2;
     $height            = 4 if $depth > 0 && $self->get_parameter('squishable_features') eq 'yes' && $self->my_config('squish');
     $height            = $self->{'extras'}{'height'} if $self->{'extras'} && $self->{'extras'}{'height'};
  
  $self->_init_bump(undef, $depth);
  
  foreach my $f (@$features) {
    my $fstrand = $f->strand || -1;
    
    next if $strand_flag eq 'b' && $strand != $fstrand;
    
    my $start = $f->start;
    my $end   = $f->end;
    
    next if $start > $slice_length || $end < 1; ## Skip if totally outside slice
    
    $start = 1             if $start < 1;
    $end   = $slice_length if $end > $slice_length;
    
    next if $optimizable && ($slice->strand < 0 ? $previous_start - $start < 0.5 / $pix_per_bp : $end - $previous_end < 0.5 / $pix_per_bp);
    
    $previous_start = $end;
    $previous_end   = $end;
    
    my $label = $no_labels ? undef : $self->feature_label($f);
    my (undef, undef, $text_width, $text_height) = $self->get_text_width(0, $label, '', font => $font, ptsize => $fontsize);
    my ($img_start, $img_end) = ($start, $end);
    my ($tag_start, $tag_end) = ($start, $end);
    my $label_start  = $start;
    my $bp_textwidth = $text_width / $pix_per_bp;
    my @tags         = grep ref $_ eq 'HASH', $self->tag($f);
    my $row          = 0;
    
    if ($label && !$label_overlay) {
      $tag_start = 1 if $tag_start < 1;
      $tag_end   = $tag_start + $bp_textwidth + 1;
      
      if ($tag_end > $image_end) {
        $tag_end     = $image_end;
        $tag_start   = $tag_end - $bp_textwidth - 1;
        $label_start = $tag_start;
      }
    }
    
    $img_start = $tag_start if $tag_start < $img_start; 
    $img_end   = $tag_end   if $tag_end   > $img_end; 
    
    foreach my $tag (@tags) {
      if ($tag->{'style'} =~ /^(left-snp|delta|box)$/) {
        $tag_start = $start - 1 - 4 / $pix_per_bp;
        $tag_end   = $start - 1 + 4 / $pix_per_bp;
      } elsif ($tag->{'style'} =~ /^(underline|fg_ends|label)$/) {
        $tag_start = $tag->{'start'} if defined $tag->{'start'};
        $tag_end   = $tag->{'end'}   if defined $tag->{'end'};
      } elsif ($tag->{'style'} =~ /^bound_triangle_(\w+)$/) {
        my $x      = $tag->{'start'} + ($tag->{'out'} == ($1 eq 'left') ? 1 : -1) * (($tag->{'out'} ? 1 : ($height / 2) + 1) / $pix_per_bp);
        $tag_start = $x - ($1 eq 'left'  ? (($height / 2) + 1) / $pix_per_bp : 0);
        $tag_end   = $x + ($1 eq 'right' ? (($height / 2) + 1) / $pix_per_bp : 0);
      } else {
        $tag_start = $tag->{'start'} || $start;
        $tag_end   = $tag->{'end'} || $end;
      }
      
      $img_start = $tag_start if $tag_start < $img_start;
      $img_end   = $tag_end   if $tag_end   > $img_end;
    }
    
    ## This is the bit we compute the width
    if ($depth > 0) { # bump
      $img_start = int($img_start * $pix_per_bp);
      $img_end   = $bump_width + int($img_end * $pix_per_bp);
      $img_end   = $img_start if $img_end < $img_start;
      $row       = $self->bump_row($img_start, $img_end);
      
      next if $row > $depth;
    }
    
    my ($pattern,$patterncolour,$notags);
    $pattern = $self->pattern($f) if $self->can('pattern');
    ($pattern,$patterncolour,$notags) = @$pattern if ref($pattern);

    my $colours   = $self->get_colours($f);
    my $composite = $self->Composite;
    my $rowheight = int($height * 1.5);
    my $part      = $colours->{'part'};
    my @tag_glyphs;
    
    if ($part eq 'line') {
      $composite->push($self->Space({
        x         => $start - 1,
        y         => 0,
        width     => $end - $start + 1,
        height    => $height,
        colour    => $colours->{'feature'},
        absolutey => 1
      }), $self->Rect({
        x         => $start - 1,
        y         => $height/2 + 1,
        width     => $end - $start + 1,
        height    => 0,
        colour    => $colours->{'feature'},
        absolutey => 1,
      }));
    } elsif ($part eq 'invisible') {
      $composite->push($self->Space({
        x          => $start - 1,
        y          => 0,
        width      => $end - $start + 1,
        height     => $height,
        absolutey  => 1
      }));
    } elsif ($part eq 'align') {
      $composite->push($self->Rect({
        x         => $start - 1,
        y         => 0,
        z         => 20,
        width     => $end - $start + 1,
        height    => $height + 2,
        colour    => $colours->{'feature'},
        absolutey => 1,
        absolutez => 1,
      }));
    } elsif ($part ne 'none') {
      my $colour_key = "$colours->{'part'}colour";
      
      $composite->push($self->Rect({
        x           => $start - 1,
        y           => 0,
        width       => $end - $start + 1,
        height      => $height,
        $colour_key => $colours->{'feature'},
        pattern     => $pattern,
        patterncolour => $patterncolour,
        absolutey   => 1,
      }));
    }
    
    push @tag_glyphs, $self->render_tags(\@tags, $composite, $slice_length, $height, $start, $end, $img_start, $img_end,$pattern,$patterncolour) unless $notags;
    
    if ($label) {
      my $font_size = $fontsize;
      
      if ($label_overlay) {
        ## Reduce text size slightly for wider letters (A, M, V, W)
        my $tmp_textwidth = $bp_textwidth;
        
        if ($bp_textwidth >= $end - $start + 1 && length $label == 1) {
          $font_size     = $fontsize * 0.9;
          $tmp_textwidth = [$self->get_text_width(0, $label, '', font => $font, ptsize => $font_size)]->[2] / $pix_per_bp;
        }
        
        ## Only add labels above a certain feature size
        if ($tmp_textwidth < $end - $start + 1) {
          my $colour = $colours->{'label'} eq $colours->{'feature'} ? $colours->{'feature'} =~ /^(black|#000000)$/ ? 'white' : 'black' : $colours->{'label'};
          $colour = $1 if $label =~ s/\{(.+?)\}//;
          $composite->push($self->Text({
            x         => $start - 1,
            y         => ($height - $text_height)/2 - 1,
            width     => $end - $start + 1,
            textwidth => $tmp_textwidth * $pix_per_bp,
            font      => $font,
            ptsize    => $font_size,
            halign    => 'center',
            height    => $text_height,
            colour    => $colour,
            text      => $label,
            absolutey => 1,
          }));
        }
      } else {
        my $label_strand = $self->my_config('label_strand');
        
        unless ($label_strand eq 'r' && $strand != -1 || $label_strand eq 'f' && $strand != 1) {
          $rowheight += $text_height + 2;
          
          my $t = $self->Composite;
          
          $t->push($composite, $self->Text({
            x         => $label_start - 1,
            y         => $height + 3,
            width     => $bp_textwidth,
            height    => $text_height,
            font      => $font,
            ptsize    => $fontsize,
            halign    => 'left',
            colour    => $colours->{'label'},
            text      => $label,
            absolutey => 1,
          }));
          
          $composite = $t;
	      }
      }
    }
    
    if ($navigation) {
      $composite->{$_} = $self->$_($f) for grep $self->can($_), qw(title href class);
    }
    
    ## Are we going to bump?
    if ($row > 0) {
      $composite->y($composite->y - $row * $rowheight * $strand);
      $_->y_transform(-$row * $rowheight * $strand) for @tag_glyphs;
    }
    
    $self->push($composite, @tag_glyphs);
    $self->highlight($f, $composite, $pix_per_bp, $height, 'highlight1', @tag_glyphs);
  }
}

sub render_tags {
  my $self = shift;
  my $tags = shift;
  my ($composite,$slice_length,$height,$_x1,$_x2,$_x3,$_x4,$pattern,$patterncolour) = @_;
  my @glyphs;
  
  foreach my $tag (@$tags) {
    if ($tag->{'style'} eq 'rect') {
      next if $tag->{'start'} > $slice_length || $tag->{'end'} < 0;
      
      my $s = $tag->{'start'} < 1 ? 1 : $tag->{'start'};
      my $e = $tag->{'end'}   > $slice_length ? $slice_length : $tag->{'end'};
      
      $composite->push($self->Rect({
        x         => $s - 1,
        y         => 0,
        width     => $e - $s + 1,
        height    => $height,
        colour    => $tag->{'colour'},
        absolutey => 1,
        pattern => $pattern,
        patterncolour => $patterncolour,
      }));
    } elsif ($tag->{'style'} eq 'join') {
      my $pos = $self->strand > 0 ? 1 : 0;
      
      $self->join_tag($composite, $tag->{'tag'},     $pos, $pos, $tag->{'colour'}, 'fill', $tag->{'zindex'} || -10);
      $self->join_tag($composite, $tag->{'tag'}, 1 - $pos, $pos, $tag->{'colour'}, 'fill', $tag->{'zindex'} || -10);
    } else {
      push @glyphs, $self->render_tag($tag, @_);
    }
  }
  
  return @glyphs;
}

sub highlight {
  my $self = shift;
  my ($f, $composite, $pix_per_bp, $height) = @_;
  
  ## Are we going to highlight this item?
  if ($self->{'config'}->get_option('opt_highlight_feature') != 0 && $f->can('display_name') && grep $_ eq $f->display_name, $self->highlights) {
    $self->unshift($self->Rect({
      x         => $composite->x - 1/$pix_per_bp,
      y         => $composite->y - 1,
      width     => $composite->width + 2/$pix_per_bp,
      height    => $height + 2,
      colour    => 'highlight1',
      absolutey => 1,
    }));
  }
}

sub render_text {
  my $self = shift;
      
  my $slice_length = $self->{'container'}->length;
  my $max_length   = $self->my_config('threshold') || 200000000;
  
  return if $slice_length > $max_length * 1010;
  
  my $features = $self->features; 
  
  return if ref $features ne 'ARRAY';
  
  my $feature_type = $self->my_config('caption');
  my $method       = $self->can('export_feature') ? 'export_feature' : '_render_text';
  my $export;

  foreach (@$features) {
    my $start = $_->start;
    my $end   = $_->end;  
    
    next if $start > $slice_length || $end < 1;  # Skip if totally outside slice
    
    $export .= $self->$method($_, $feature_type);
  }
  
  return $export;
}

1;
