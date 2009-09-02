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
  my $species_2      = $self->my_config('species_hr');
  my $method         = $self->my_config('method');
  my $depth          = $self->my_config('depth') || 6;
  my $feature_colour = $self->my_colour($feature_key);
  my $join_col       = $self->my_colour($feature_key, 'join')   || 'gold'; 
  my $join_z         = $self->my_colour($feature_key, 'join_z') || 100;
  my $h              = $self->get_parameter('opt_halfheight') ? 4 : 8;
  my $link           = $self->get_parameter('compara') ? $self->my_config('join') : 0;
  my $block          = 0;
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
    my $start      = $features[0][1]->hstart;
    my $end        = $features[0][1]->hend;
    my $bump_start = (($features[0][0] < 1 ? 1 : $features[0][0]) * $pix_per_bp) - 1;
    my $bump_end   = ($features[-1][1]->end > $length ? $length : $features[-1][1]->end) * $pix_per_bp;
    my $row        = $self->bump_row(int $bump_start, int $bump_end);
    
    next if $row > $depth;
    
    my $y_pos = -$row * int(1.5 * $h) * $strand;
    my $x = -1000000;
    
    my $composite = $self->Composite({
      'x'     => $features[0][0] > 1 ? $features[0][0] - 1 : 0,
      'y'     => 0,
      'width' => 0
    });
    
    foreach (@features) {
      my $f = $_->[1];
      
      $start = $f->hstart if $f->hstart < $start;
      $end   = $f->hend   if $f->hend   > $end;
      
      next if int($f->end * $pix_per_bp) <= int($x * $pix_per_bp);
      
      $c++;
      
      if ($draw_cigar) {
        $self->draw_cigar_feature($composite, $f, $h, $feature_colour, 'black', $pix_per_bp, 1);
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
          $self->join_tag($box, 'BLOCK_' . $self->_type . $block, {
            x     => $strand == -1 ? 0 : 1,
            y     => $strand == -1 ? 1 : 0,
            z     => $join_z,
            col   => $join_col,
            style => 'fill'
          });
          
          $self->join_tag($box, 'BLOCK_' . $self->_type . $block, {
            x     => $strand == -1 ? 1 : 0,
            y     => $strand == -1 ? 1 : 0,
            z     => $join_z,
            col   => $join_col,
            style => 'fill'
          });
          
          $block++;
        }
        
        $composite->push($box);
      }
    }
    
    $composite->y($composite->y + $y_pos);
    $composite->bordercolour($feature_colour);
    
    # add more detailed links for non chained alignments
    # CURRENTLY APPEARS TO BE REDUNDANT - Something for dotter view?
    #    if (scalar @features == 1) {
    #      my $chr_2 = $features[0][1]->hseqname;
    #      my $s_2   = $features[0][1]->hstart;
    #      my $e_2   = $features[0][1]->hend;
    #      my $END   = $features[0][1]->end;
    #      my $START = $features[0][0];
    #      
    #      ($START, $END) = ($END, $START) if $END < $START; # Flip start end
    #      
    #      my ($rs, $re)     = $self->slice2sr($START, $END);
    #      my $jump_type     = $species_2;
    #      my $short_self    = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{$self_species};
    #      my $short_other   = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{$other_species};
    #      my $href_template = "/$short_self/dotterview?c=$chr:%d;s1=$other_species;c1=%s:%d";
    #      my $compara_html_extra;
    #      
    #      $zmenu->{'method'} = $self->my_config('type');
    #      
    #      my $href = sprintf $href_template, ($rs + $re)/2, $chr_2, ($s_2 + $e_2)/2;
    #      my $method = $self->my_config('method');
    #      my $link = 0;
    #      my $tag_prefix;
    #      
    #      if ($compara) {
    #        $link = $self->my_config('join');
    #        $tag_prefix  = uc($compara eq 'primary' ? join ('_', $method, $self_species, $other_species) : join ('_', $method, $other_species, $self_species));
    #        
    #        my $c = 1;
    #        
    #        foreach my $T (@{$self->{'config'}{'other_slices'}||[]}) {
    #          if ($T->{'species'} ne $self_species && $T->{'species'} ne $other_species) {
    #            $c++;
    #            $compara_html_extra .=" ;s$c=" . $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{$T->{'species'}};
    #          }
    #        }
    #      }
    #    }
    
    $composite->href($self->_url({
      type   => 'Location',
      action => 'ComparaGenomicAlignment',
      r1     => $features[0][1]->hseqname . ":$start-$end",
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
  
  my $depth          = $self->my_config('depth');
  
  $self->_init_bump(undef, $depth);  # initialize bumping

  my $length         = $container->length;
  my $pix_per_bp     = $self->scalex;
  my $draw_cigar     = $pix_per_bp > 0.2;
  my $feature_key    = lc $self->my_config('type');
  my $other_species  = $self->my_config('species');
  my $species_2      = $self->my_config('species_hr');
  my $method         = $self->my_config('method');
  my $feature_colour = $self->my_colour($feature_key);
  my $join_col       = $self->my_colour($feature_key, 'join')   || 'gold'; 
  my $join_z         = $self->my_colour($feature_key, 'join_z') || 100;
  my $h              = $self->get_parameter('opt_halfheight') ? 4 : 8;
  my $self_species   = $container->{'web_species'};
  my $chr            = $container->seq_region_name;
  my $short_self     = $self->species_defs->ENSEMBL_SHORTEST_ALIAS->{$self_species};
  my $c              = 0;
  my $domain         = $self->my_config('linkto');
  my $href_template  = "/$short_self/dotterview?c=$chr:%d;s1=$other_species;c1=%s:%d";
  my $x              = -1e8;

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
    
    my @X = (
      [ $chr, int(($rs + $re)/2) ],
      [ $f->hseqname, int(($f->hstart + $f->hend)/2) ],
      int($width/2),
      $f->hseqname . ':' . $f->hstart . '-' . $f->hend,
      "$chr:$rs-$re"
    );
    
    my $to_push;
    my $chr_2 = $f->hseqname; 
    my $s_2   = $f->hstart;
    my $e_2   = $f->hend;
    my $href  = sprintf $href_template, ($rs + $re)/2, $chr_2, ($s_2 + $e_2)/2;
    
    # zmenu links depend on whether jumping within or between species;
    my $zmenu = {
      type   => 'Location',
      action => 'ComparaGenomicAlignment',
      r      => "$chr:$rs-$re",
      r1     => "$chr_2:$s_2-$e_2",
      s1     => $other_species,
      method => $self->my_config('type'),
      orient => $f->hstrand * $f->strand > 0 ? 'Forward' : 'Reverse'
    };
    
    if ($draw_cigar) {
      $to_push = $self->Composite({
        href  => $self->_url($zmenu),
        x     => $start - 1,
        width => 0,
        y     => 0
      });
      
      $self->draw_cigar_feature($to_push, $f, $h, $feature_colour, 'black', $pix_per_bp, 1);
      $to_push->bordercolour($feature_colour);
    } else {
      $to_push = $self->Rect({
        x         => $start - 1,
        y         => 0,
        width     => $end - $start + 1,
        height    => $h,
        colour    => $feature_colour,
        absolutey => 1,
        _feature  => $f, 
        href      => $self->_url($zmenu)
      });
    }
    
    $self->push($to_push);
  }
  
  # No features show "empty track line" if option set
  $self->errorTrack(sprintf 'No %s features in this region', $self->my_config('name')) unless $c || $self->get_parameter('opt_empty_tracks') == 0;
}

sub features {
  my $self = shift;
  
  return $self->{'container'}->get_all_compara_DnaAlignFeatures(
    $self->my_config('species_hr'),
    $self->my_config('assembly'),
    $self->my_config('type'),
    $self->dbadaptor('multi', $self->my_config('db'))
  );
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
