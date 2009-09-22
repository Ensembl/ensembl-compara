package Bio::EnsEMBL::GlyphSet::_alignment_pairwise;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub render_normal {
  my $self = shift;
  
  return $self->render_text if $self->{'text_export'};
  
  my $width       = 1e5;
  my $container   = $self->{'container'};
  my $strand      = $self->strand;
  my $strand_flag = $self->my_config('strand');
  
  return if $strand_flag eq 'r' && $strand != -1;
  return if $strand_flag eq 'f' && $strand !=  1;
  
  my $self_species   = $container->{'web_species'};
  my $length         = $container->length;
  my $pix_per_bp     = $self->scalex;
  my $draw_cigar     = $pix_per_bp > 0.2;
  my $feature_key    = lc $self->my_config('type');
  my $other_species  = $self->my_config('species');
  my $other_ori      = $self->my_config('ori');
  my $depth          = $self->my_config('depth') || 6;
  my $feature_colour = $self->my_colour($feature_key);
  my $join_col       = $self->my_colour($feature_key, 'join')   || 'gold'; 
  my $join_z         = $self->my_colour($feature_key, 'join_z') || 100;
  my $h              = $self->get_parameter('opt_halfheight') ? 4 : 8;
  my $link           = $self->get_parameter('compara') ? $self->my_config('join') : 0;
  my $c              = 0; # Diagnostic counter
  my $k              = 0; # Diagnostic counter
  my %ids;
  
  $self->_init_bump(undef, $depth); # initialize bumping
  
  foreach my $f (@{$self->features||[]}) {
    next if $strand_flag eq 'b' && $strand != $f->hstrand || $f->end < 1 || $f->start > $length;
    
    push @{$ids{$f->hseqname . ':' . ($f->group_id || ('00' . $k++))}}, [ $f->start, $f ];
  }
  
  # sort alignments by size
  my @sorted = sort { ($ids{$b}[0][1]->hend - $ids{$b}[0][1]->hstart) <=> ($ids{$a}[0][1]->hend - $ids{$a}[0][1]->hstart) } keys %ids;
  
  foreach my $i (@sorted) {
    my ($seqregion) = split /:/, $i;
    
    my @features   = sort { $a->[0] <=> $b->[0] } @{$ids{$i}};
    my $hs         = $features[0][1]->hstart;
    my $he         = $features[0][1]->hend;
    my $bump_start = (($features[0][0] < 1 ? 1 : $features[0][0]) * $pix_per_bp) - 1;
    my $bump_end   = ($features[-1][1]->end > $length ? $length : $features[-1][1]->end) * $pix_per_bp;
    my $row        = $self->bump_row(int $bump_start, int $bump_end);
    
    next if $row > $depth;
    
    my $y_pos = -$row * int(1.5 * $h) * $strand;
    my $x = -1000000;
    
    my $composite = $self->Composite({
      x     => $features[0][0] > 1 ? $features[0][0] - 1 : 0,
      y     => 0,
      width => 0
    });
    
    foreach (@features) {
      my $f = $_->[1];
      
      $hs = $f->hstart if $f->hstart < $hs;
      $he = $f->hend   if $f->hend   > $he;
      
      next if int($f->end * $pix_per_bp) <= int($x * $pix_per_bp);
      
      $c++;
      
      if ($draw_cigar) {
        $self->draw_cigar_feature({
          composite      => $composite, 
          feature        => $f, 
          height         => $h, 
          feature_colour => $feature_colour, 
          delete_colour  => 'black', 
          scalex         => $pix_per_bp, 
          do_not_flip    => 1,
          link           => $link,
          join_col       => $join_col,
          join_z         => $join_z,
          other_ori      => $other_ori
        });
      } else {
        my $s = $_->[0] < 1 ? 1 : $_->[0];
        my $e = $f->end > $length ? $length : $f->end;
        
        $x = $e;
        
        my $box = $self->Rect({
          x         => $s - 1,
          y         => 0,
          width     => $e - $s + 1,
          height    => $h,
          colour    => $feature_colour,
          absolutey => 1
        });
        
        if ($link) {
          my $slice_start = $f->slice->start;
          my $slice_end   = $f->slice->end;
          my $fstrand     = $f->strand;
          my $hstrand     = $f->hstrand;
          my $s1          = $fstrand == 1 ? $slice_start + $f->start - 1 : $slice_end - $f->end   + 1;
          my $e1          = $fstrand == 1 ? $slice_start + $f->end   - 1 : $slice_end - $f->start + 1;
          my $tag1        = join ':', $f->species, $f->slice->seq_region_name, $s1, $e1;
          my $tag2        = join ':', $f->hspecies, $f->hseqname, $f->hstart, $f->hend;
          my $tag         = $strand == 1 ? "$tag1#$tag2" : "$tag2#$tag1";
          my $x;
          
          if ($other_ori == $hstrand && $other_ori == 1) {
            $x = $strand == -1 ? 0 : 1; # Use the opposite value to normal to ensure alignments which are between different orientations by default do not display a cross-over join
          } else {
            $x = $strand == -1 ? 1 : 0;
          }
          
          $x ||= 1 if $fstrand == 1 && $hstrand * $other_ori == -1; # the feature has been flipped, so force x to the same value each time to achieve a cross-over join
          
          $self->join_tag($box, $tag, {
            x     => $x,
            y     => $strand == -1 ? 1 : 0,
            z     => $join_z,
            col   => $join_col,
            style => 'fill'
          });
          
          $self->join_tag($box, $tag, {
            x     => !$x,
            y     => $strand == -1 ? 1 : 0,
            z     => $join_z,
            col   => $join_col,
            style => 'fill'
          });
        }
        
        $composite->push($box);
      }
    }
    
    $composite->y($composite->y + $y_pos);
    $composite->bordercolour($feature_colour);
    
    $composite->href($self->_url({
      type   => 'Location',
      action => 'ComparaGenomicAlignment',
      r1     => $features[0][1]->hseqname . ":$hs-$he",
      s1     => $other_species,
      orient => $features[0][1]->hstrand * $features[0][1]->strand > 0 ? 'Forward' : 'Reverse'
    }));
    
    $self->push($composite);
  }
  
  # No features show "empty track line" if option set
  $self->errorTrack(sprintf 'No %s features in this region', $self->my_config('name')) unless $c || $self->get_parameter('opt_empty_tracks') == 0;
  $self->timer_push('Features drawn');
}

sub render_compact {
  my $self = shift;
  
  return $self->render_text if $self->{'text_export'};
  
  my $width          = 1e5;
  my $container      = $self->{'container'};
  my $strand         = $self->strand;
  my $strand_flag    = $self->my_config('strand');
  
  return if $strand_flag eq 'r' && $strand != -1;
  return if $strand_flag eq 'f' && $strand !=  1;
  
  my $self_species   = $container->{'web_species'};
  my $length         = $container->length;
  my $chr            = $container->seq_region_name;
  my $pix_per_bp     = $self->scalex;
  my $draw_cigar     = $pix_per_bp > 0.2;
  my $feature_key    = lc $self->my_config('type');
  my $other_species  = $self->my_config('species');
  my $other_ori      = $self->my_config('ori');
  my $depth          = $self->my_config('depth');
  my $feature_colour = $self->my_colour($feature_key);
  my $join_col       = $self->my_colour($feature_key, 'join')   || 'gold'; 
  my $join_z         = $self->my_colour($feature_key, 'join_z') || 100;
  my $h              = $self->get_parameter('opt_halfheight') ? 4 : 8;
  my $link           = $self->get_parameter('compara') ? $self->my_config('join') : 0;
  my $c              = 0;
  my $x              = -1e8;

  $self->_init_bump(undef, $depth);  # initialize bumping 
  
  my @features = sort { $a->[0] <=> $b->[0] }
    map  { [ $_->start, $_ ] }
    grep { !(($strand_flag eq 'b' && $strand != $_->hstrand) || ($_->start > $length) || ($_->end < 1)) } 
    @{$self->features||[]};
  
  foreach (@features) {
    my ($start, $f) = @$_;
    my $end = $f->end;
    
    ($start, $end) = ($end, $start) if $end < $start; # Flip start end
    
    my ($rs, $re) = $self->slice2sr($start, $end);
    
    $start = 1 if $start < 1;
    $end   = $length if $end > $length;
    
    next if int($end * $pix_per_bp) == int($x * $pix_per_bp);
    
    $x = $start;
    $c++;
    
    my $composite;
    (my $url_species = $f->species) =~ s/ /_/g;
    
    # zmenu links depend on whether jumping within or between species;
    my $zmenu = {
      type    => 'Location',
      action  => 'ComparaGenomicAlignment',
      species => $url_species,
      r       => "$chr:$rs-$re",
      r1      => $f->hseqname . ':' . $f->hstart . '-' . $f->hend,
      s1      => $other_species,
      method  => $self->my_config('type'),
      orient  => $f->hstrand * $f->strand > 0 ? 'Forward' : 'Reverse'
    };
    
    if ($draw_cigar) {
      $composite = $self->Composite({
        href  => $self->_url($zmenu),
        x     => $start - 1,
        width => 0,
        y     => 0
      });
      
      $self->draw_cigar_feature({
        composite      => $composite, 
        feature        => $f, 
        height         => $h, 
        feature_colour => $feature_colour, 
        delete_colour  => 'black', 
        scalex         => $pix_per_bp, 
        do_not_flip    => 1,
        link           => $link,
        join_col       => $join_col,
        join_z         => $join_z,
        other_ori      => $other_ori
      });
      
      $composite->bordercolour($feature_colour);
    } else {
      $composite = $self->Rect({
        x         => $start - 1,
        y         => 0,
        width     => $end - $start + 1,
        height    => $h,
        colour    => $feature_colour,
        absolutey => 1,
        _feature  => $f, 
        href      => $self->_url($zmenu)
      });
      
      if ($link) {
        my $slice_start = $f->slice->start;
        my $slice_end   = $f->slice->end;
        my $fstrand     = $f->strand;
        my $hstrand     = $f->hstrand;
        my $s1          = $fstrand == 1 ? $slice_start + $f->start - 1 : $slice_end - $f->end   + 1;
        my $e1          = $fstrand == 1 ? $slice_start + $f->end   - 1 : $slice_end - $f->start + 1;
        my $tag1        = join ':', $f->species, $f->slice->seq_region_name, $s1, $e1;
        my $tag2        = join ':', $f->hspecies, $f->hseqname, $f->hstart, $f->hend;
        my $tag         = $strand == 1 ? "$tag1#$tag2" : "$tag2#$tag1";
        my $x;
        
        if ($other_ori == $hstrand && $other_ori == 1) {
          $x = $strand == -1 ? 0 : 1; # Use the opposite value to normal to ensure alignments which are between different orientations by default do not display a cross-over join
        } else {
          $x = $strand == -1 ? 1 : 0;
        }
        
        $x ||= 1 if $fstrand == 1 && $hstrand * $other_ori == -1; # the feature has been flipped, so force x to the same value each time to achieve a cross-over join
        
        $self->join_tag($composite, $tag, {
          x     => $x,
          y     => $strand == -1 ? 1 : 0,
          z     => $join_z,
          col   => $join_col,
          style => 'fill'
        });
        
        $self->join_tag($composite, $tag, {
          x     => !$x,
          y     => $strand == -1 ? 1 : 0,
          z     => $join_z,
          col   => $join_col,
          style => 'fill'
        });
      }
    }
    
    $self->push($composite);
  }
  
  # No features show "empty track line" if option set
  $self->errorTrack(sprintf 'No %s features in this region', $self->my_config('name')) unless $c || $self->get_parameter('opt_empty_tracks') == 0;
}

sub features {
  my $self = shift;
  
  my $features = $self->{'container'}->get_all_compara_DnaAlignFeatures(
    $self->my_config('species_hr'),
    $self->my_config('assembly'),
    $self->my_config('type'),
    $self->dbadaptor('multi', $self->my_config('db'))
  );
  
  my $target = $self->my_config('target');
  
  $features = [ grep $_->hseqname eq $target, @{$features||[]} ] if $target;
  
  return $features;
}

sub render_text {
  my $self = shift;
  
  my $strand = $self->strand;
  my $strand_flag = $self->my_config('strand');
  
  return if $strand_flag eq 'r' && $strand != -1;
  return if $strand_flag eq 'f' && $strand != 1;

  my $length  = $self->{'container'}->length;
  my $species = $self->my_config('species');
  my $type    = $self->my_config('type');
  my $export;
  
  foreach my $f (@{$self->features||[]}) {
    next if $strand_flag eq 'b' && $strand != $f->hstrand || $f->end < 1 || $f->start > $length;
    
    $export .= $self->_render_text($f, $type, { 
      headers => [ $species ], 
      values  => [ $f->hseqname . ':' . $f->hstart . '-' . $f->hend ]
    }, {
      strand => '.',
      frame  => '.'
    });
  }
  
  return $export;
}

1;
