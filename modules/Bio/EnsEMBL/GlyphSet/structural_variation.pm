package Bio::EnsEMBL::GlyphSet::structural_variation;

use strict;

use List::Util qw(min max);

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub somatic    { return $_[0]->{'my_config'}->id =~ /somatic/; }
sub colour_key { 
  if($_[1]->is_somatic and $_[1]->breakpoint_order) {
    return "somatic_breakpoint_variant";
  }
  return $_[1]->class_SO_term;
}

sub features {
  my $self     = shift; 
  my $slice    = $self->{'container'};
  my $source   = $self->my_config('source');
  my $set_name = $self->my_config('set_name');
  my $func     = $self->somatic ? 'get_all_somatic_StructuralVariationFeatures' : 'get_all_StructuralVariationFeatures';
  my $id       = $self->{'my_config'}->id;
  my ($min_length,$max_length) = split('-', $self->my_config('length'));
  my $overlap  = $self->my_config('overlap');
  
  my $features;
  if (!$self->cache($id)) {
    my $features;
    my @display_features;
    
    if ($set_name) {
      $features = $slice->get_all_StructuralVariationFeatures_by_VariationSet($self->{'config'}->hub->get_adaptor('get_VariationSetAdaptor', 'variation')->fetch_by_name($set_name)) if $set_name;
    } 
    else {
      my @display_features;
      
      $features = $slice->$func($source =~ /^\w/ ? $source : undef);
      
      # Dispatch the SV features in the 2 "overlap" tracks
      if (defined($overlap)) {
    
        for (my $i=0;$i<scalar(@$features);$i++) {
          my $seq_start = $features->[$i]->seq_region_start;
          my $seq_end   = $features->[$i]->seq_region_end;
          if ($overlap == 1) {
            push (@display_features, $features->[$i]) if ($seq_start >= $slice->start || $seq_end <= $slice->end);
          } elsif ($overlap == 2) {
            push (@display_features, $features->[$i]) if ($seq_start < $slice->start && $seq_end > $slice->end);
          }
        }
        $features = \@display_features;
        
      } 
      # Display only the correct breakpoint (somatic data)
      elsif ($self->somatic) {
      
        for (my $i=0;$i<scalar(@$features);$i++) {
          if (!$features->[$i]->{breakpoint_order}) {
            push (@display_features,$features->[$i]);
            next;
          }
          my $seq_start = $features->[$i]->seq_region_start;
          my $seq_end   = $features->[$i]->seq_region_end;
          if (($seq_start >= $slice->start && $seq_start <= $slice->end) || 
              ($seq_end >= $slice->start && $seq_end <= $slice->end)) 
          {
            push (@display_features, $features->[$i]);
          }
        }
        $features = \@display_features;
        
      }
    }
    $self->cache($id, $features);
  }
  my $sv_features = $self->cache($id) || [];
  
  return $sv_features;
}


sub tag {
  my ($self, $f) = @_;
  my $colour = $self->my_colour($self->colour_key($f), 'tag');
  my @tags;
  
  if ($f->is_somatic && $f->breakpoint_order) {
    my $slice = $self->{'container'};
    my $seq_start = $f->seq_region_start;
    my $seq_end   = $f->seq_region_end;
      
    my @coords;
    push (@coords, $f->start) if ($seq_start >= $slice->start && $seq_start <= $slice->end);
    push (@coords, $f->end) if ($f->start!=$f->end && ($seq_end >= $slice->start && $seq_end <= $slice->end));
   
     foreach my $coord (@coords) {
      push @tags,{
        style  => $self->my_colour($self->colour_key($f), 'style'),
        colour => 'gold',
        start  => $coord,
        end    => $coord+10
      };
    }
  } 
  else {
    my $border         = 'dimgray';
    my $inner_crossing = $f->inner_start && $f->inner_end && $f->inner_start >= $f->inner_end ? 1 : 0;

  
    if ($inner_crossing && $f->inner_start == $f->seq_region_end) {
      return {
        style  => 'rect',
        colour => $colour,
        border => $border,
        start  => $f->start,
        end    => $f->end
      };
    }
  
    # start of feature
    if ($f->outer_start && $f->inner_start) {
      if ($f->outer_start != $f->inner_start && !$inner_crossing) {
        push @tags, {
          style => 'rect',
          start => $f->start,
          end   => $f->inner_start - $f->seq_region_start + $f->start
        };
      }
    } elsif ($f->outer_start) {
      if ($f->outer_start == $f->seq_region_start || $inner_crossing) {
        push @tags, {
          style => 'bound_triangle_right',
          start => $f->start,
          out   => 1
        };
      }
    } elsif ($f->inner_start) {
      if ($f->inner_start == $f->seq_region_start && !$inner_crossing) {
        push @tags, {
          style => 'bound_triangle_left',
          start => $f->start
        };
      }
    }
  
    # end of feature
    if ($f->outer_end && $f->inner_end) {
      if ($f->outer_end != $f->inner_end && !$inner_crossing) {
        push @tags, {
          style => 'rect',
          start => $f->end - $f->seq_region_end + $f->inner_end,
          end   => $f->end
        };
      }
    } elsif ($f->outer_end) {
      if ($f->outer_end == $f->seq_region_end || $inner_crossing) {
        push @tags, {
          style => 'bound_triangle_left',
          start => $f->end,
          out   => 1
        };
      }
    } elsif ($f->inner_end) {
      if ($f->inner_end == $f->seq_region_end && !$inner_crossing) {
        push @tags, {
          style => 'bound_triangle_right',
          start => $f->end
        };
       }
    }
  
    foreach (@tags) {
      $_->{'colour'} = $colour;
      $_->{'border'} = $border;
    }
  }
  
  return @tags;
}

sub render_tag {
  my ($self, $tag, $composite, $slice_length, $width, $start, $end, $img_start, $img_end) = @_;
  my $pix_per_bp = $self->scalex;
  my @glyph;
  
  if ($tag->{'style'} =~ /^bound_triangle_(\w+)$/ && $img_start < $tag->{'start'} && $img_end > $tag->{'end'}) {
    my $pix_per_bp = $self->scalex;
    my $x          = $tag->{'start'} + ($tag->{'out'} == ($1 eq 'left') ? 1 : -1) * (($tag->{'out'} ? 1 : ($width / 2) + 1) / $pix_per_bp);
    my $y          = $width / 2;
    
    # Triangle returns an array: the triangle, and an invisible rectangle behind it for clicking purposes
    @glyph = $self->Triangle({
      mid_point    => [ $x, $y ],
      colour       => $tag->{'colour'},
      bordercolour => $tag->{'border'},
      absolutey    => 1,
      width        => $width,
      height       => $y / $pix_per_bp,
      direction    => $1,
    });
  } elsif ($tag->{'style'} eq 'none') {
    my $h     = $self->my_config('height') || [$self->get_text_width(0, 'X', '', $self->get_font_details($self->my_config('font') || 'innertext'), 1)]->[3] + 2;
    my $x     = $tag->{'start'};
    my $y     = $h / 2;
    my $width = 10 / $self->scalex;
    $y = $h*2;
    my $scale = ($y/4)/$pix_per_bp;

    my $points = [ $x,            1,              # 1
                   $x+$scale,     1,              # 2
                   $x+$scale/10,  $y/2-$y/6+1,    # 3
                   $x+$scale*1.2, $y/2-$y/6+1,    # 4
                   $x,            $y-2,           # 5
                   $x,            $y-$y/2+$y/6-1, # 6
                   $x-$scale/2,   $y-$y/2+$y/6-1  # 7
                 ];
                          
    my $points2 = [ $x-$scale/5,   0,             # 1
                     $x+$scale*1.6, 0,            # 2
                     $x+$scale*0.8, $y/2-$y/6,    # 3
                     $x+$scale*1.9, $y/2-$y/6,    # 4
                     $x+$scale/10,  $y,           # 5a
                     $x-$scale/10,  $y,           # 5b 
                     $x-$scale/5,   $y-$y/2+$y/6, # 6
                     $x-$scale*1.2, $y-$y/2+$y/6  # 7
                   ];  
    @glyph = (
             $self->Poly({
               'points'    => $points2,
               'colour'    => 'black',
               'z'         => 5,
             }),
             $self->Poly({
               'points'    => $points,
               'colour'    => $tag->{'colour'},
               'z'         => 10,
             }) 
    );
    $composite->push(
             $self->Rect({
               'z'         => 1,
               'x'         => $x-$scale*1.2,
               'width'     => $scale*3.1,
               'height'    => $y,
               'absolutey' => 1,
             })
    );
  }
  
  return @glyph;
}


sub href {
  my ($self, $f) = @_;
  
  if ($self->my_config('depth') == 1) {
    return $self->_url({
      species  => $self->species,
      type     => 'StructuralVariationGroup',
      r        => $f->seq_region_name.':'.$self->{'container'}{'start'}.'-'.$self->{'container'}{'end'},
      length   => $self->my_config('length'),
    });
  } else {
    return $self->_url({
      type => 'StructuralVariation',
      sv   => $f->variation_name,
      svf  => $f->dbID,
      vdb  => 'variation'
    });
  }
}

sub title {
  my ($self, $f) = @_;
  my $id     = $f->variation_name;
  my $start  = $self->{'container'}->start + $f->start -1;
  my $end    = $self->{'container'}->end + $f->end;
  my $pos    = 'Chr ' . $f->seq_region_name . ":$start-$end";
  my $source = $f->source;

  return "Structural variation: $id; Source: $source; Location: $pos";
}

sub highlight {
  my ($self, $f, $composite, $pix_per_bp, $h, undef, @tags) = @_;
  
  return unless $self->core('sv') eq $f->variation_name;
  
  my $width = max(map $_->width, $composite, @tags);
  my $x     = min(map $_->x,     $composite, @tags);
  
  if ($f->is_somatic and $f->breakpoint_order) {
    $self->unshift($self->Rect({
      x            => $x - 1/$pix_per_bp,
      y            => $composite->y - 1,
      width        => $width + 2/$pix_per_bp,
      height       => $h*2 + 2,
      bordercolour => 'green',
      absolutey    => 1,
    }));
  } else {
    $self->unshift($self->Rect({
      x            => $x - 1/$pix_per_bp,
      y            => $composite->y - 1,
      width        => $width + 2/$pix_per_bp,
      height       => $h + 2,
      bordercolour => 'green',
      absolutey    => 1,
    }));
  }
}

1;
