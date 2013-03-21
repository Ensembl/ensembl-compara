package Bio::EnsEMBL::GlyphSet::structural_variation;

use strict;

use List::Util qw(min max);

use base qw(Bio::EnsEMBL::GlyphSet_simple);

sub somatic    { return $_[0]->{'my_config'}->id =~ /somatic/; }

sub colour_key {

  return 'copy_number_variation' if ($_[0]->{'display'} eq 'compact');
  
  return 'somatic_breakpoint_variant' if ($_[1]->is_somatic and $_[1]->breakpoint_order );
  
  if ($_[1]->class_SO_term eq 'copy_number_variation') {
    my $ssv_class = $_[1]->structural_variation->get_all_supporting_evidence_classes;
    return $ssv_class->[0] if (scalar @$ssv_class == 1);
  }
  return $_[1]->class_SO_term;
}

sub my_config { 
  my $self = shift;
  my $term = shift;
  
  if ($term eq 'depth') {
    my $depth = ($self->{'my_config'}->get($term) > 1) ? $self->{'my_config'}->get($term) : 100;
    return ($self->{'display'} eq 'compact') ? 1 : $depth;
  }
  
  if ($term eq 'height') {
    return ($self->my_config('depth') > 1) ? 6 : 12;
  }
  
  return $self->{'my_config'}->get($term);
}

sub features {
  my $self = shift; 
  my $config = $self->{'config'};
  my $id   = $self->{'my_config'}->id;
  
  if (!$self->cache($id)) {
    my $slice    = $self->{'container'};
    my $set_name = $self->my_config('set_name');
    my $features;
    
    if ($set_name) {
      $features = $slice->get_all_StructuralVariationFeatures_by_VariationSet($self->{'config'}->hub->get_adaptor('get_VariationSetAdaptor', 'variation')->fetch_by_name($set_name));
    } else {
      my $func    = $self->somatic ? 'get_all_somatic_StructuralVariationFeatures' : 'get_all_StructuralVariationFeatures';
      my $source  = $self->my_config('source');
      my $overlap = $self->my_config('overlap');
      my $start   = $slice->start;
      my $end     = $slice->end;
      my @display_features;
      
      $features = $slice->$func($source =~ /^\w/ ? $source : undef);
      
      # Dispatch the SV features in the 2 "overlap" tracks
      if (defined $overlap) {
        for (my $i = 0; $i < scalar @$features; $i++) {
          my $seq_start = $features->[$i]->seq_region_start;
          my $seq_end   = $features->[$i]->seq_region_end;
          
          if ($overlap == 1) {
            push @display_features, $features->[$i] if $seq_start >= $start || $seq_end <= $end;
          } elsif ($overlap == 2) {
            push @display_features, $features->[$i] if $seq_start < $start && $seq_end > $end;
          }
        }
        
        # Generate blocks when the track is compacted in one line (except for the Larger Structural Variants track)
        if ($overlap != 2 && $self->{'display'} eq 'compact') {
        
          my $slice_adaptor = $self->{'container'}->adaptor->db->get_db_adaptor('core')->get_SliceAdaptor;
          my @list = sort {$a->seq_region_start <=> $b->seq_region_start}  @display_features;
          @display_features = ();
          my $block_nb = 1;
          for (my $i=0;$i<scalar(@list);$i++) {
            my $svf  = $list[$i];
            my $start = $svf->seq_region_start;
            my $end   = $svf->seq_region_end;
            my $b_start = $start;
            my $b_end   = $end;
            while ($b_end >= $start) {
              if ($b_end < $end) {
                $b_end = $end;
              }
              last if ($i == (scalar(@list)-1));
              my $svf2 = $list[$i+1];
              $start = $svf2->seq_region_start;
              $end   = $svf2->seq_region_end;
              $i ++ if ($b_end >= $start);
            }
            $b_end = $self->{'container'}{'end'} if ($b_end > $self->{'container'}{'end'});
            my $sv_block = Bio::EnsEMBL::Variation::StructuralVariationFeature->new
                           (
                             -start => $b_start-$slice->start+1,
                             -end   => $b_end-$slice->start+1,
                             -slice => $slice
                           );
            $block_nb ++;
            push (@display_features, $sv_block);
          }
        }

        $features = \@display_features;
         
      } elsif ($self->somatic) {  # Display only the correct breakpoint (somatic data)
        for (my $i = 0; $i < scalar @$features; $i++) {
          if (!$features->[$i]{'breakpoint_order'}) {
            push @display_features, $features->[$i];
            next;
          }
          
          my $seq_start = $features->[$i]->seq_region_start;
          my $seq_end   = $features->[$i]->seq_region_end;
          
          push @display_features, $features->[$i] if ($seq_start >= $start && $seq_start <= $end) || ($seq_end >= $start && $seq_end <= $end);
        }
        
        $features = \@display_features;
      }
    }
    
    $self->{'legend'}{'structural_variation_legend'}{$self->colour_key($_)} = $self->get_colours($_)->{'feature'} for @$features;

    $self->cache($id, $features);
  }
  
  return $self->cache($id) || [];
}


sub tag {
  my ($self, $f) = @_;
  my $colour = $self->my_colour($self->colour_key($f), 'tag');
  my @tags;
  
  if ($f->is_somatic && $f->breakpoint_order) {
    foreach my $coords ([ $f->start, $f->seq_region_start ], $f->start != $f->end ? [ $f->end, $f->seq_region_end ] : ()) {
      next if ($coords->[0] < 0);
      push @tags, {
        style       => 'somatic_breakpoint',
        colour      => 'gold',
        border      => 'black',
        start       => $coords->[0],
        slice_start => $coords->[1]
      };
    }
  } else {
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
    
    return @tags if ($self->my_config('depth') <= 1);
    
  
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
      z            => 10
    });
  } elsif ($tag->{'style'} eq 'somatic_breakpoint') {
    my $slice = $self->{'container'};
    
    if ($tag->{'slice_start'} >= $slice->start && $tag->{'slice_start'} <= $slice->end) {
      my $x     = $tag->{'start'};
      my $y     = 2 * ($self->my_config('height') || [$self->get_text_width(0, 'X', '', $self->get_font_details($self->my_config('font') || 'innertext'), 1)]->[3] + 2);
      my $scale = 1 / $pix_per_bp;
      
      @glyph = $self->Poly({
        z            => 10,
        colour       => $tag->{'colour'},
        bordercolour => $tag->{'border'},
        points       => [
          $x - 0.5 * $scale, 1,
          $x + 4.5 * $scale, 1,
          $x + 2.5 * $scale, $y / 3 + 1,
          $x + 5.5 * $scale, $y / 3 + 1,
          $x,                $y, 
          $x + 0.5 * $scale, $y * 2 / 3 - 1,
          $x - 3.5 * $scale, $y * 2 / 3 - 1
        ],
      });
      
      $composite->push($self->Rect({
        z         => 1,
        x         => $x - 3.5 * $scale,
        width     => 9 * $scale,
        height    => $y,
        absolutey => 1,
      }));
    }
  }
  
  return @glyph;
}

sub href {
  my ($self, $f) = @_;
  
  if ($self->my_config('depth') == 1) {
    my $start = ($self->{'container'}{'start'} > $f->seq_region_start) ? $self->{'container'}{'start'} : $f->seq_region_start; 
    my $end   = ($self->{'container'}{'end'} < $f->seq_region_end) ? $self->{'container'}{'end'} : $f->seq_region_end; 
    
    my $overlap = ($self->my_config('overlap')) ? $self->my_config('overlap') : undef;
    
    my $is_somatic = ($f->is_somatic) ? 1 : undef;
    
    return $self->_url({
      species  => $self->species,
      type     => 'StructuralVariationGroup',
      r        => $f->seq_region_name.":$start-$end",
      length   => $self->my_config('length'),
      group    => $overlap,
      somatic  => $is_somatic
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
  
  return unless ($self->my_config('depth') > 1 && $self->core('sv') eq $f->variation_name);
  
  my $width = max(map $_->width, $composite, @tags);
  my $x     = min(map $_->x,     $composite, @tags);
  
  $self->unshift($self->Rect({
    x            => $x - 1/$pix_per_bp,
    y            => $composite->y - 1,
    width        => $width + 2/$pix_per_bp,
    height       => $h * ($f->is_somatic && $f->breakpoint_order ? 2 : 1) + 2,
    bordercolour => 'green',
    absolutey    => 1,
  }));
}

1;
