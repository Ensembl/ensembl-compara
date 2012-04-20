package Bio::EnsEMBL::GlyphSet::somatic_structural_variation;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::structural_variation);

sub my_label { return 'Somatic structural variations'; }

sub features {
  my $self     = shift; 
  my $slice    = $self->{'container'};
  my $source   = $self->my_config('source');

  my $var_features;
  
  # Structural variations by source
  if ($source =~ /^\w/) {
    $var_features = $slice->get_all_somatic_StructuralVariationFeatures($source);
  } 
  # All structural variations
  else {
    $var_features = $slice->get_all_somatic_StructuralVariationFeatures;
  }
  
  if ($self->my_config('display') eq 'normal') {
    $self->get_render_normal;
  }
  
  return $var_features;  
}


sub tag {
  my ($self, $f) = @_;
  
  my $colour         = $self->my_colour($self->colour_key($f), 'tag');
  my $inner_crossing = $f->inner_start && $f->inner_end && $f->inner_start >= $f->inner_end ? 1 : 0;
  my @g_objects;

  if ($f->start == $f->end) {
    push @g_objects, {
      style  => 'breakpoint',
      start  => $f->start,
      colour => 'gold'
    };
  }
  else {
    # start of feature
    if ($f->outer_start && $f->inner_start) {
      if ($f->outer_start != $f->inner_start && !$inner_crossing) {
        push @g_objects, {
          style  => 'rect',
          colour => $colour,
          start  => $f->start,
          end    => $f->inner_start - $f->seq_region_start + $f->start
        };
      }
    } elsif ($f->outer_start) {
      if ($f->outer_start == $f->seq_region_start || $inner_crossing) {
         push @g_objects, {
          style  => 'bound_triangle_right',
           colour => $colour,
          start  => $f->start,
          out    => 1
        };
      }
    } elsif ($f->inner_start) {
      if ($f->inner_start == $f->seq_region_start && !$inner_crossing) {
        push @g_objects, {
          style  => 'bound_triangle_left',
          colour => $colour,
          start  => $f->start
        };
      }
    }
  
    # end of feature
    if ($f->outer_end && $f->inner_end) {
      if ($f->outer_end != $f->inner_end && !$inner_crossing) {
        push @g_objects, {
          style  => 'rect',
          colour => $colour,
          start  => $f->end - $f->seq_region_end + $f->inner_end,
          end    => $f->end
        };
      }
    } elsif ($f->outer_end) {
      if ($f->outer_end == $f->seq_region_end || $inner_crossing) {
        push @g_objects, {
          style  => 'bound_triangle_left',
          colour => $colour,
          start  => $f->end,
          out    => 1
        };
      }
    } elsif ($f->inner_end) {
      if ($f->inner_end == $f->seq_region_end && !$inner_crossing) {
        push @g_objects, {
          style  => 'bound_triangle_right',
          colour => $colour,
          start  => $f->end
        };
      }
    }
  }
  
  return @g_objects;
} 


sub render_tag {
  my ($self, $tag, $composite, $slice_length, $width, $start, $end, $img_start, $img_end) = @_;
  my @glyph;
  
  if ($tag->{'style'} =~ /^bound_triangle_(\w+)$/ && $img_start < $tag->{'start'} && $img_end > $tag->{'end'}) {
    my $pix_per_bp = $self->scalex;
    my $x          = $tag->{'start'} + ($tag->{'out'} == ($1 eq 'left') ? 1 : -1) * ($tag->{'out'} ? 0 : $width / 2 / $pix_per_bp);
    my $y          = $width / 2;
    
    # Triangle returns an array: the triangle, and an invisible rectangle behind it for clicking purposes
    @glyph = $self->Triangle({
      mid_point    => [ $x, $y ],
      colour       => $tag->{'colour'},
      absolutey    => 1,
      width        => $width,
      height       => $y / $pix_per_bp,
      direction    => $1,
      bordercolour => 'black',
    });
  }
  elsif ($tag->{'style'} eq 'breakpoint' && $img_start < $tag->{'start'} && $img_end > $tag->{'end'}) {
    my $pix_per_bp = $self->scalex;
    my ($font, $fontsize) = $self->get_font_details($self->my_config('font') || 'innertext');
    my $h           = $self->my_config('height') || [$self->get_text_width(0, 'X', '', font => $font, ptsize => $fontsize)]->[3] + 2;
  
    my $x          = $tag->{'start'};
    my $y          = $h/2;
    my $tr_width   = 10 / $pix_per_bp;
    
    # Triangle returns an array: the triangle, and an invisible rectangle behind it for clicking purposes
    @glyph = (
      $self->Triangle({
        mid_point    => [ $x, $y ],
        colour       => $tag->{'colour'},
        absolutey    => 1,
        width        => $tr_width,
        height       => $y,
        direction    => 'up',
        bordercolour => 'GoldenRod',
        z            => 12,
      }),
      $self->Triangle({
        mid_point    => [ $x, ($y/2)+2 ],
        colour       => $tag->{'colour'},
        absolutey    => 1,
        width        => $tr_width,
        height       =>  $y,
        direction    => 'down',
        bordercolour => 'GoldenRod',
        z            => 12,
      }),
      
    );
  }
  
  return @glyph;
}


sub highlight {
  my ($self, $f, $composite, $pix_per_bp, $h) = @_;
  my $id = $f->variation_name;
  my %highlights;
  @highlights{$self->highlights} = (1);

  my $length = ($f->end - $f->start) + 1; 
  
  return unless $highlights{$id};
  
  my $tr_width = ($composite->width == 1) ? 5 : 0;
  
  $h *= 2 if ($self->my_config('display') eq 'normal' && $composite->width == 1 );
  
  # First a black box
  $self->unshift($self->Rect({
      x         => $composite->x - (2+$tr_width)/$pix_per_bp,
      y         => $composite->y - 2, # + makes it go down
      width     => $composite->width + (4+$tr_width*2)/$pix_per_bp,
      height    => $h + 4,
      colour    => 'black',
      absolutey => 1,
    }),
    $self->Rect({ # Then a 1 pixel smaller green box
      x         => $composite->x - (1+$tr_width)/$pix_per_bp,
      y         => $composite->y - 1, # + makes it go down
      width     => $composite->width + (2+$tr_width*2)/$pix_per_bp,
      height    => $h + 2,
      colour    => 'white',
      absolutey => 1,
    }),
    # Masks the Glyphset_simple object drawn by default (rect of 1 pb)
    $self->Rect({ # Then a 1 pixel smaller green box
      x         => $composite->x,
      y         => $composite->y, # + makes it go down
      width     => 1,
      height    => $h,
      colour    => 'white',
      absolutey => 1,
      z         => 10
    }));
}

1;
