package Bio::EnsEMBL::GlyphSet::alignscalebar;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::scalebar);

sub _init {
  my $self = shift;

  my $container     = $self->{'container'};  
  my $contig_strand = $container->can('strand') ? $container->strand : 1;
  my $strand        = $self->strand;
  my $compara       = $self->get_parameter('compara');
  
  my $global_start = $contig_strand < 0 ? -$container->end : $container->start;
  my $global_end   = $contig_strand < 0 ? -$container->start : $container->end;
  
  $self->label($self->Text({ text => '' })) if $strand < 0;
  
  $self->render_align_gap($global_start, $global_end);
  $self->render_align_bar($global_start, $global_end, 5);
  $self->render_scalebar($strand > 0 ? 0 : 20) if ($compara eq 'primary' && $strand > 0) || ($compara ne 'primary' && $strand < 0);
  
  # Draw the species separator line
  if ($strand > 0 && $compara ne 'primary') {
    my $line = $self->Rect({
      'x'             => -120,
      'y'             => 0,
      'colour'        => 'black',
      'width'         => 20000,
      'height'        => 0,
      'absolutex'     => 1,
      'absolutewidth' => 1,
      'absolutey'     => 1
    });
      
    $self->push($line);
  }
}

# Display gaps in AlignSlices
sub render_align_gap {
  my $self = shift;
  my ($global_start, $global_end) = @_;

  my $container = $self->{'container'};
  my $y = $self->strand > 0 ? 8 : 2;
  
  my $mp = $container->{'slice_mapper_pairs'};
  my $si = 0;
  my $hs = $mp->[$si];
  my $gs = $hs->{'start'} - 1;
  my $ge = $hs->{'end'};

  my $cigar_line = $container->get_cigar_line;

  # Display only those gaps that amount to more than 1 pixel on screen, otherwise screen gets white when you zoom out too much
  my $min_length = 1 / $self->scalex;

  my @inters = split /([MDG])/, $cigar_line;
  
  my $ms = 0;
  my $box_start = 0;
  my $box_end = 0;
  my $colour = 'white';
  my $z = -10;

  while (@inters) {
    $ms = shift @inters || 1;
    
    my $mtype = shift @inters;
    
    $box_end = $box_start + $ms - 1;
    
    # Skip normal alignment and gaps in alignments
    $box_start = $box_end + 1 and next if $mtype =~ /G|M/;
    
    if ($box_start > $ge) {
      $si++;
      $hs = $mp->[$si] or return;
      $gs = $hs->{'start'} - 1;
      $ge = $hs->{'end'};
    }
    
    if ($ms > $min_length && $box_start >= $gs && $box_end < $ge) { 
      my $glyph = $self->Rect({
        'x'         => $box_start,
        'y'         => $y,
        'z'         => $z,
        'width'     => abs($box_end - $box_start + 1),
        'height'    => 3,
        'colour'    => $colour, 
        'absolutey' => 1
      });
      
      $self->push($glyph);
      
      if ($self->{'strand'} < 0) {
        $self->join_tag($glyph, "alignsliceG_$box_start", 0, 0, $colour, 'fill', $z);
        $self->join_tag($glyph, "alignsliceG_$box_start", 1, 0, $colour, 'fill', $z);
      } else {
        $self->join_tag($glyph, "alignsliceG_$box_start", 1, 1, $colour, 'fill', $z);
        $self->join_tag($glyph, "alignsliceG_$box_start", 0, 1, $colour, 'fill', $z);
      }
    }
    
    $box_start = $box_end + 1;
  }
}

# Display AlignSlice bars
sub render_align_bar {
  my $self = shift;
  
  my ($global_start, $global_end, $yc) = @_;
  
  my $species = $self->species;
  my $mp = $self->{'container'}->{'slice_mapper_pairs'};
  
  my $pix_per_bp  = $self->scalex;
  my $last_end = -1;
  my $last_chr = -1;
  my $zc = -20;
  my $last_s2s = -1;
  my $last_s2e = -1;
  my $last_s2st = 0;

  my %colour_map;
  my %colour_map2;
  my @colours2 = qw(antiquewhite3 brown gray rosybrown1 blue green red gray yellow);
  my @colours = qw(antiquewhite1 mistyrose1 burlywood1 khaki1 cornsilk1 lavenderblush1 lemonchiffon2 darkseagreen2 lightcyan1 papayawhip seashell1);

  foreach my $s (sort {$a->{'start'} <=> $b->{'start'}} @$mp) {
    my $s2 = $s->{'slice'};
    
    my $ss = $s->{'start'};
    my $sst = $s->{'strand'};
    my $se = $s->{'end'};
    
    my $s2s = $s2->{'start'};
    my $s2e = $s2->{'end'};
    my $s2st = $s2->{'strand'};
    my $s2t = $s2->{'seq_region_name'};
    
    my $box_start = $ss;
    my $box_end   = $se;
    my $filled = $sst;
    my $s2l = abs($s2e - $s2s) + 1;
    my $sl = abs($se - $ss) + 1;
    
    my ($title, $href);
    
    if ($s2t eq 'GAP') {
      $title = 'AlignSlice; Gap in the alignment';
    } elsif ($species eq 'Ancestral_sequences') {
      $title = "AlignSlice; ID: $s2t; $s2->{'_tree'}";
    } else {
      $href = $self->_url({ 
        species  => $species,
        r        => "$s2t:$s2s-$s2e",
        strand   => $s2st,
        interval => "$ss-$se"
      });
    }
    
    $colour_map{$s2t}  ||= shift @colours || 'grey';
    $colour_map2{$s2t} ||= 'darksalmon';
    
    my $col2 = $colour_map2{$s2t};
    
    my $t = $self->Rect({
      x         => $box_start - $global_start, 
      y         => $yc,
      width     => abs($box_end - $box_start + 1),
      height    => 3,
      absolutey => 1,
      title     => $title,
      href      => $href,
      ($filled == 1 ? 'colour' : 'bordercolour') => $col2
    });
    
    $self->push($t);
    
    my $col = $colour_map{$s2t};
    
    if ($self->{'strand'} < 0) {
      $self->join_tag($t, "alignslice_$box_start", 0, 0, $col, 'fill', $zc);
      $self->join_tag($t, "alignslice_$box_start", 1, 0, $col, 'fill', $zc);
    } else {
      $self->join_tag($t, "alignslice_$box_start", 1, 1, $col, 'fill', $zc);
      $self->join_tag($t, "alignslice_$box_start", 0, 1, $col, 'fill', $zc);
    }
    
    # This happens when we have two contiguous underlying slices
    if ($last_end == $ss - 1) {
      my $s3l = $s2s - $last_s2e - 1;
      
      if ($s2st == -1 && $last_s2st == -1) {
        $s3l = $s2e - $last_s2s + 1;
      }
      
      my $xc = $box_start - $global_start;
      my $h = $yc - 2;
      
      my $colour;
      
      $href = '';
      
      if ($last_chr ne $s2t) {
        # Different chromosomes
        $colour = 'black';
        $title = "AlignSlice Break; There is a breakpoint in the alignment between chromosome $last_chr and $s2t";
      } elsif ($last_s2st ne $s2st) {
        # Same chromosome, different strand (inversion)
        $colour = '3333ff';
        $title = "AlignSlice Break; Info: There is an inversion in chromosome $s2t";
      } elsif ($s3l > 0) {
        # Same chromosome, same strand, gap between the two underlying slices
        my ($from, $to);
        $colour = 'red';
        
        if ($s2st == 1) {
          $from = $last_s2e;
          $to = $s2s;
        } else {
          $from = $s2e;
          $to = $last_s2s;
        }
        
        $href = $self->_url({
          species => $species,
          r       => "$s2t:$from-$to",
          break   => 1
        });
      } else {
        # Same chromosome, same strand, no gap between the two underlying slices (BreakPoint in another species)
        $colour = 'indianred3';
        $title = "AlignSlice Break; There is a breakpoint in the alignment on chromosome $s2t";
      }
      
      $self->push($self->Poly({
        points    => [ 
          $xc - 2/$pix_per_bp, $h,
          $xc, $h + 6,
          $xc + 2/$pix_per_bp, $h
        ],
        colour    => $colour,
        absolutey => 1,
        title     => $title,
        href      => $href
      }));
    }
    
    $last_end = $se;
    $last_s2s = $s2s;
    $last_s2e = $s2e;
    $last_s2st = $s2st;
    $last_chr = $s2t;
  }
}

1;
