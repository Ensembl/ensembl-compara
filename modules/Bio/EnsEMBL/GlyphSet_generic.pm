package Bio::EnsEMBL::GlyphSet_generic;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

use Sanger::Graphics::Bump;


sub features {
  return [];
} 

use Bio::EnsEMBL::Feature;

sub _draw_features {
  my( $self, $ori, $features, $render_flags ) = @_;

  $self->_init_bump();
  my $ppbp    = $self->scalex;
  my $seq_len = $self->{'container'}->length;
  my $h       = $features->{'max_height'} || 8;
  my $colour = $ori ? 'blue' : 'green';
  foreach my $lname    ( sort keys %{$features->{'groups'}} ) {
    foreach my $gkey  ( sort keys %{$features->{'groups'}{$lname}} ) {
      my $group = $features->{'groups'}{$lname}{$gkey}{$ori};
      next unless $group;
## We now have a feature....
## Now let us grab all the features in the group as we need to work out the width of the "group"
## which may be wider than the feature if
##   (a) we have labels (width of label if wider than feature)
##   (b) have fixed width glyphs at points
##   (c) have histogram data - has nos to left of graph..

## Start with looking for special "aggregator glyphs"
#       foreach my $style_key ( keys %{ $group->{'features'} } ) {
#         if( $features->{'f_styles'}{$style_key}{'symbol'} =~ /^(histogram|tiling)$/ ) { ## We need to prepend width with of label!
#
#         }
#       }

      next if $group->{'end'} < 1 || $group->{'start'} > $seq_len; ## Can't draw group!
      my $s = $group->{'start'}<1?1:$group->{'start'};
      my $e = $group->{'end'}  >$seq_len?$seq_len:$group->{'end'};
      my $row = $self->bump_row( $group->{'start'}*$ppbp, $group->{'end'}*$ppbp );
      $self->push($self->Rect({
        'absolutey' => 1,
        'x'         => $s,
        'width'     => $e-$s+1,
        'y'         => $row * ($h+2),
        'height'    => $h,
        'colour'    => 'papayawhip',
        'title'     => $group->{label}.' : '.$group->{id}
      }));
      foreach my $style_key ( sort { $features->{'f_style'}{$a}{'style'}{'zindex'} <=> $features->{'f_style'}{$b}{'style'}{'zindex'} }  keys %{$group->{'features'}} ) {
        foreach my $f ( @{$group->{'features'}{$style_key}} ) {
          my $fs = $f->start;
          my $fe = $f->end;
          next if $fe < 1;
          next if $fs > $seq_len;
          $fs = 1        if $fs < 1;
          $fe = $seq_len if $fs < 1;

          $self->push($self->Rect({
           'absolutey' => 1,
           'x'         => $fs,
           'width'     => $fe-$fs+1,
           'y'         => $row * ($h+2),
           'height'    => $h,
           'bordercolour' => 'red',
          }));
        }
      }
    }
  }
}

sub render_nolabel {
  my $self = shift;
  $self->render_normal( 'nolabel' );
}

sub render_label_on {
  my $self = shift;
  $self->render_normal( 'label_on' );
}

sub render_label_under {
  my $self = shift;
  $self->render_normal( 'label_under' );
}

sub render_normal {
  my ($self, $render_flags ) = @_;
  $self->{'y_offset'} = 0;

  ## Grab and cache features as we need to find out which strands to draw them on!
  my $features = $self->cache( 'generic:'.$self->{'my_config'}->key );
  $features = $self->cache( 'generic:'.$self->{'my_config'}->key, $self->features() ) unless $features;
  
  $self->timer_push( 'Fetched DAS features', undef, 'fetch' );

  my $strand          = $self->strand();

  my $y_offset = 0; ## Useful to track errors!!

  if( @{$features->{'errors'}} ) { ## If we have errors then we will uniquify and sort!
    my %saw = map { ($_,1) } @{$features->{'errors'}};
    $self->errorTrack( $_, undef, $self->{'y_offset'}+=12 ) foreach sort keys %saw;
  }

  ## Draw stranded features first!!
  $self->_draw_features( $strand, $features, $render_flags ) if $features->{'ori'}{$strand};
  ## Draw unstranded features last !! So they go below stranded features!
  $self->_draw_features( 0, $features, $render_flags ) if $features->{'ori'}{0} && $strand == -1;

  return;
}
## Which strand to render on!

1;

## Two sorts of renderer! - composite renderers - work on every element in the collection!

sub extent_histogram {
  my($self,$g,$st) = @_;
}

sub composite_histogram {
  my($self,$g,$f_ref,$st) = @_; ## These have passed in the group + all the features in the group!
}

sub extent_gradient {
  my($self,$g,$st) = @_;
  return ($g->{start},$g->{end});
}

sub composite_gradient {
  my($self,$g,$f_ref,$st) = @_;
}

sub extent_lineplot {
  my($self,$g,$st) = @_;
  return $self->extent_histogram($g,$st);
}

sub composite_lineplot {
  my($self,$g,$f_ref,$st) = @_;

}

sub extent_signalmap {
  my($self,$g,$st) = @_;
  return $self->extent_histogram($g,$st);
}

sub composite_signalmap {
  my($self,$g,$f_ref,$st) = @_;

}

## - glyph renderers - work on individual elements

sub extent_anchored_arrow {
  my($self,$f,$st)= @_;
  return $self->extent_box($f,$st);
}

sub glyph_anchored_arrow {
  my($self,$g,$f,$st)= @_;
}

sub extent_arrow {
  my($self,$f,$st)= @_;

}

sub glyph_arrow {
  my($self,$g,$f,$st)= @_;

}

sub extent_box {
  my($self,$f,$st)= @_;
  return ($f->start,$f->end);
}

sub glyph_box {
  my($self,$g,$f,$st)= @_;
  
}

sub extent_cross {
  my($self,$f,$st)= @_;
}

sub glyph_cross {
  my($self,$g,$f,$st)= @_;

}

sub extent_dot {
  my($self,$f,$st)= @_;
}

sub glyph_dot {
  my($self,$g,$f,$st)= @_;

}

sub extent_ex {
  my($self,$f,$st)= @_;

}

sub glyph_ex {
  my($self,$g,$f,$st)= @_;

}

sub extent_hidden {
  my($self,$f,$st)= @_;

}

sub glyph_hidden {
  my($self,$g,$f,$st)= @_;

}

sub extent_line {
  my($self,$f,$st)= @_;

}

sub glyph_line {
  my($self,$g,$f,$st)= @_;

}

sub extent_primers {
  my($self,$f,$st)= @_;
  return $self->extent_box($f,$st);
}

sub glyph_primers {
  my($self,$g,$f,$st)= @_;

}

sub extent_span {
  my($self,$f,$st)= @_;
  return $self->extent_box($f,$st);
}

sub glyph_span {
  my($self,$g,$f,$st)= @_;

}

sub extent_text {
  my($self,$f,$st)= @_;

}

sub glyph_text {
  my($self,$g,$f,$st)= @_;

}

sub extent_toomany {
  my($self,$f,$st)= @_;
  return $self->extent_box($f,$st);
}

sub glyph_toomany {
  my($self,$g,$f,$st)= @_;

}

sub extent_triangle {
  my($self,$f,$st)= @_;

}

sub glyph_triangle {
  my($self,$f,$st)= @_;

}

__END__

sub _x {
  my $self = shift;
  my $strand_flag     = $self->my_config( 'strand' );
  my $strand          = $self->strand();

  my $features = [];
  my $slice = $self->{'container'};
  my($FONT,$FONTSIZE) = $self->get_font_details( $self->my_config('font') || 'innertext' );
  my $BUMP_WIDTH      = $self->my_config( 'bump_width');
  $BUMP_WIDTH         = 1 unless defined $BUMP_WIDTH;
  
  ## If only displaying on one strand skip IF not on right strand....
  return if $strand_flag eq 'r' && $strand != -1;
  return if $strand_flag eq 'f' && $strand != 1;

  # Get information about the VC - length, and whether or not to
  # display track/navigation               
  my $slice_length   = $slice->length( );
  my $max_length     = $self->my_config( 'threshold' )            || 200000000;
  my $navigation     = $self->my_config( 'navigation' )           || 'on';
  my $max_length_nav = $self->my_config( 'navigation_threshold' ) || 15000000;
  
  if( $slice_length > $max_length *1010 ) {
    $self->errorTrack( $self->my_config('caption')." only displayed for less than $max_length Kb.");
    return;
  }

  ## Decide whether we are going to include navigation (independent of switch) 
  $navigation = ($navigation eq 'on') && ($slice_length <= $max_length_nav *1010);

  ## Set up bumping bitmap    

  ## Get information about bp/pixels    
  my $pix_per_bp     = $self->scalex;
  my $bitmap_length  = int($slice->length * $pix_per_bp);
  ## And the colours
  my $dep            = $self->my_config('depth')||100000;
  $self->_init_bump( undef, $dep );

  my $flag           = 1;
  my($temp1,$temp2,$temp3,$H) = $self->get_text_width(0,'X','','font'=>$FONT,'ptsize' => $FONTSIZE );
  my $th = $H;
  my $tw = $temp3;
  my $h  = $self->my_config('height') || $H+2;
  if(
    $dep>0 &&
    $self->get_parameter(  'squishable_features' ) eq 'yes' &&
    $self->my_config('squish')
  ) {
    $h = 4;
  }
  if( $self->{'extras'} && $self->{'extras'}{'height'} ) {
    #warn 
    $h = $self->{'extras'}{'height'};
  }
  my $previous_start = $slice_length + 1e9;
  my $previous_end   = -1e9 ;
  my ($T,$C,$C1) = 0;
  my $optimizable = $self->my_config('optimizable') && $dep<1 ; #at the moment can only optimize repeats...
  

#  my $features = $self->features(); 

  unless(ref($features)eq'ARRAY') {
    # warn( ref($self), ' features not array ref ',ref($features) );
    return; 
  }

  my $aggregate = '';
  
  if( $aggregate ) {
    ## We need to set max depth to 0.1
    ## We need to remove labels (Zmenu becomes density score)
    ## We need to produce new features for each bin
    my $aggregate_function = "aggregate_$aggregate";
    $features = $self->$aggregate_function( $features ); 
  }

  foreach my $f ( @{$features} ) { 
    #print STDERR "Added feature ", $f->id(), " for drawing.\n";
    ## Check strand for display ##
    my $fstrand = $f->strand || -1;
    next if( $strand_flag eq 'b' && $strand != $fstrand );

    ## Check start are not outside VC.... ##
    my $start = $f->start();
    next if $start>$slice_length; ## Skip if totally outside VC
    $start = 1 if $start < 1;  
    ## Check end are not outside VC.... ##
    my $end   = $f->end();   
    next if $end<1;            ## Skip if totally outside VC
    $end   = $slice_length if $end>$slice_length;
    $T++;
    next if $optimizable && ( $slice->strand() < 0 ?
                                $previous_start-$start < 0.5/$pix_per_bp : 
                                $end-$previous_end     < 0.5/$pix_per_bp );
    $C ++;
    $previous_end   = $end;
    $previous_start = $end;
    $flag = 0;
    my $img_start = $start;
    my $img_end   = $end;
    my( $label,      $style ) = $self->feature_label( $f, $tw );
    my( $txt, $part, $W, $H ) = $self->get_text_width( 0, $label, '', 'font' => $FONT, 'ptsize' => $FONTSIZE );
    my $bp_textwidth = $W / $pix_per_bp;
    
    my( $tag_start ,$tag_end) = ($start, $end);
    if( $label && $style ne 'overlaid' ) {
      $tag_start = ( $start + $end - 1 - $bp_textwidth ) /2;
      $tag_start = 1 if $tag_start < 1;
      $tag_end   = $tag_start + $bp_textwidth;
    }
    $img_start = $tag_start if $tag_start < $img_start; 
    $img_end   = $tag_end   if $tag_end   > $img_end; 
    my @tags = $self->tag($f);
    foreach my $tag (@tags) { 
      next unless ref($tag) eq 'HASH';
      $tag_start = $start; 
      $tag_end = $end;    
      if($tag->{'style'} eq 'snp' ) {
        $tag_start = $start - 1/2 - 4/$pix_per_bp;
        $tag_end   = $start - 1/2 + 4/$pix_per_bp;
      } elsif( $tag->{'style'} eq 'left-snp' || $tag->{'style'} eq 'delta' || $tag->{'style'} eq 'box' ) {
        $tag_start = $start - 1 - 4/$pix_per_bp;
        $tag_end   = $start - 1 + 4/$pix_per_bp;
      } elsif($tag->{'style'} eq 'right-snp') {
        $tag_start = $end - 4/$pix_per_bp;
        $tag_end   = $end + 4/$pix_per_bp;
      } elsif($tag->{'style'} eq 'underline') {
        $tag_start = $tag->{'start'} if defined $tag->{'start'};
        $tag_end   = $tag->{'end'}   if defined $tag->{'end'};
      } elsif($tag->{'style'} eq 'fg_ends') {
        $tag_start = $tag->{'start'} if defined $tag->{'start'};
        $tag_end   = $tag->{'end'}   if defined $tag->{'end'};
      }
      $img_start = $tag_start if $tag_start < $img_start; 
      $img_end   = $tag_end   if $tag_end   > $img_end;  
    } 
    ## This is the bit we compute the width.... 
        
    my $row = 0;
    if ($dep > 0){ # we bump
      $img_start = int($img_start * $pix_per_bp);
      $img_end   = $BUMP_WIDTH + int( $img_end * $pix_per_bp );
      $img_end   = $img_start if $img_end < $img_start;
      $row = $self->bump_row( $img_start, $img_end );
      next if $row > $dep;
    }
    my @tag_glyphs = ();

    my $colours        = $self->get_colours($f);
    # warn "$colour_key - $colours->{'feature'}, $colours->{'label'}";
    
    ## Lets see about placing labels on objects...        
    my $composite = $self->Composite();
    if($colours->{'part'} eq 'line') {
      #    print STDERR "PUSHING LINE\n"; 
      $composite->push( $self->Space({
        'x'          => $start-1,
        'y'          => 0,
        'width'      => $end - $start + 1,
        'height'     => $h,
        "colour"     => $colours->{'feature'},
        'absolutey'  => 1
                               }));
      $composite->push( $self->Rect({
        'x'          => $start-1,
        'y'          => $h/2+1,
        'width'      => $end - $start + 1,
        'height'     => 0,
        "colour"     => $colours->{'feature'},
        'absolutey'  => 1
      }));
    } elsif( $colours->{'part'} eq 'invisible' ) {
      $composite->push( $self->Space({
        'x'          => $start-1,
        'y'          => 0,
        'width'      => $end - $start + 1,
        'height'     => $h,
        'absolutey'  => 1
      }) );
    } elsif( $colours->{'part'} eq 'align' ) {
      $composite->push( $self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'z' => 20,
          'width'      => $end - $start + 1,
          'height'     => $h+2,
          "colour"     => $colours->{'feature'},
          'absolutey'  => 1,
          'absolutez'  => 1,
      }) );
    } else {
      $composite->push( $self->Rect({
        'x'          => $start-1,
        'y'          => 0,
        'width'      => $end - $start + 1,
        'height'     => $h,
        $colours->{'part'}."colour" => $colours->{'feature'},
        'absolutey'  => 1
      }) );
    }
    my $rowheight = int($h * 1.5);

    foreach my $tag ( @tags ) {
      next unless ref($tag) eq 'HASH';
      if($tag->{'style'} eq 'left-end' && $start == $f->start) {
        ## Draw a line on the left hand end....
        $composite->push($self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'width'      => 0,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
      } elsif($tag->{'style'} eq 'right-end' && $end == $f->end) {
        ## Draw a line on the right hand end....
        $composite->push($self->Rect({
          'x'          => $end,
          'y'          => 0,
          'width'      => 0,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
      } elsif($tag->{'style'} eq 'insertion') {
        my $triangle_end   =  $start-1 - 2/$pix_per_bp;
        my $triangle_start =  $start-1 + 2/$pix_per_bp;
        push @tag_glyphs, $self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'width'      => 0,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }),$self->Poly({
          'points'    => [ $triangle_start, $h+2,
                           $start-1, $h-1,
                           $triangle_end, $h+2  ],
          'colour'    => $tag->{'colour'},
          'absolutey' => 1,
        });
      } elsif($tag->{'style'} eq 'left-triangle') {
         my $triangle_end = $start -1 + 3/$pix_per_bp;
            $triangle_end = $end if( $triangle_end > $end);
         push @tag_glyphs, $self->Poly({
           'points'    => [ $start-1, 0,
                            $start-1, 3,
                            $triangle_end, 0  ],
           'colour'    => $tag->{'colour'},
           'absolutey' => 1,
         });
      } elsif($tag->{'style'} eq 'right-snp') {
        next if($end < $f->end());
        my $triangle_start =  $end - 1/2 + 4/$pix_per_bp;
        my $triangle_end   =  $end - 1/2 + 4/$pix_per_bp;
        $composite->push($self->Space({
          'x'          => $triangle_start,
          'y'          => $h,
          'width'      => 8/$pix_per_bp,
          'height'     => 0,
          'colour'     => $tag->{'colour'},
          'absolutey'  => 1
        }));
        push @tag_glyphs, $self->Poly({
           'points'    => [ $triangle_start, $h,
                            $end - 1/2,      0,
                            $triangle_end,   $h  ],
           'colour'    => $tag->{'colour'},
           'absolutey' => 1,
        });
      } elsif($tag->{'style'} eq 'snp') {
        next if( $tag->{'start'} < 1) ;
        next if( $tag->{'start'} > $slice_length );
        my $triangle_start =  $tag->{'start'} - 1/2 - 4/$pix_per_bp;
        my $triangle_end   =  $tag->{'start'} - 1/2 + 4/$pix_per_bp;
        $composite->push($self->Space({
          'x'          => $triangle_start,
          'y'          => $h,
          'width'      => 8/$pix_per_bp,
          'height'     => 0,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
        push @tag_glyphs, $self->Poly({
          'points'    => [ $triangle_start, $h,
                           $tag->{'start'} - 1/2 , 0,
                           $triangle_end,   $h  ],
          'colour'    => $tag->{'colour'},
          'absolutey' => 1,
        });
      } elsif($tag->{'style'} eq 'rect') {
        next if $tag->{'start'} > $slice_length;
        next if $tag->{'end'}   < 0;
        my $s = $tag->{'start'} < 1 ? 1 : $tag->{'start'};
        my $e = $tag->{'end'}   > $slice_length ? $slice_length : $tag->{'end'}; 
        $composite->push($self->Rect({
          'x'          => $s-1,
          'y'          => 0,
          'width'      => $e-$s+1,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
      } elsif($tag->{'style'} eq 'box') {
        next if($start > $f->start());
        my $triangle_start =  $start - 1/2 - 4/$pix_per_bp;
        my $triangle_end   =  $start - 1/2 + 4/$pix_per_bp;
        $composite->push($self->Rect({
          'x'          => $triangle_start,
          'y'          => 1,
          'width'      => 8/$pix_per_bp,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
        my @res = $self->get_text_width( 0, $tag->{'letter'},'', 'font'=>$FONT, 'ptsize' => $FONTSIZE );
        my $tmp_width = $res[2]/$pix_per_bp;
        $composite->push($self->Text({
          'x'          => ($end + $start - 1/4 - $tmp_width)/2,
          'y'          => ($h-$H)/2,
          'width'      => $tmp_width,
          'textwidth'  => $res[2],
          'height'     => $H,
          'font'       => $FONT,
          'ptsize'     => $FONTSIZE,
          'halign'     => 'center',
          'colour'     => $tag->{'label_colour'},
          'text'       => $tag->{'letter'},
          'absolutey'  => 1,
        }));
      } elsif($tag->{'style'} eq 'delta') {
        next if($start > $f->start());
        my $triangle_start =  $start - 1/2 - 4/$pix_per_bp;
        my $triangle_end   =  $start - 1/2 + 4/$pix_per_bp;
        $composite->push($self->Space({
          'x'          => $triangle_start,
          'y'          => $h,
          'width'      => 8/$pix_per_bp,
          'height'     => 0,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
        push @tag_glyphs, $self->Poly({
          'points'    => [ $triangle_start, 0,
                           $start - 1/2   , $h,
                           $triangle_end  , 0  ],
          'colour'    => $tag->{'colour'},
          'absolutey' => 1,
        });
      } elsif($tag->{'style'} eq 'left-snp') {
        next if($start > $f->start());
        my $triangle_start =  $start - 1/2 - 4/$pix_per_bp;
        my $triangle_end   =  $start - 1/2 + 4/$pix_per_bp;
        $composite->push($self->Space({
          'x'          => $triangle_start,
          'y'          => $h,
          'width'      => 8/$pix_per_bp,
          'height'     => 0,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
        push @tag_glyphs, $self->Poly({
          'points'    => [ $triangle_start, $h,
                           $start - 1/2   , 0,
                           $triangle_end  , $h  ],
          'colour'    => $tag->{'colour'},
          'absolutey' => 1,
        });
      } elsif($tag->{'style'} eq 'right-triangle') {
        my $triangle_start =  $end - 3/$pix_per_bp;
        $triangle_start = $start if( $triangle_start < $start);
        push @tag_glyphs, $self->Poly({
          'points'    => [ $end, 0,
                           $end, 3,
                           $triangle_start, 0  ],
          'colour'    => $tag->{'colour'},
          'absolutey' => 1,
        });
      } elsif($tag->{'style'} eq 'underline') {
        my $underline_start = $tag->{'start'} || $start ;
        my $underline_end   = $tag->{'end'}   || $end ;
        $underline_start = 1          if $underline_start < 1;
        $underline_end   = $slice_length if $underline_end   > $slice_length;
        $composite->push($self->Rect({
          'x'          => $underline_start -1 ,
          'y'          => $h,
          'width'      => $underline_end - $underline_start + 1,
          'height'     => 0,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
      } elsif($tag->{'style'} eq 'fg_ends') {
        my $f_start = $tag->{'start'} || $start ;
        my $f_end   = $tag->{'end'}   || $end ;
        $f_start = 1          if $f_start < 1;
        $f_end   = $slice_length if $f_end   > $slice_length;
        $composite->push( $self->Rect({
          'x'          => $f_start -1 ,
          'y'          => ($h/2),
          'width'      => $f_end - $f_start + 1,
          'height'     => 0,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1,
          'zindex'     => 0  
        }),$self->Rect({
          'x'          => $f_start -1 ,
          'y'          => 0,
          'width'      => 0,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'zindex'  => 1
        }),$self->Rect({
          'x'          => $f_end,
          'y'          => 0,
          'width'      => 0,
          'height'     => $h,
          "colour"     => $tag->{'colour'},
          'zindex'  => 1
        }) );
      } elsif($tag->{'style'} eq 'line') {
        my $underline_start = $tag->{'start'} || $start ;
        my $underline_end   = $tag->{'end'}   || $end ;
        $underline_start = 1          if $underline_start < 1;
        $underline_end   = $slice_length if $underline_end   > $slice_length;
        $composite->push($self->Rect({
          'x'          => $underline_start -1 ,
          'y'          => $h/2,
          'width'      => $underline_end - $underline_start + 1,
          'height'     => 0,
          "colour"     => $tag->{'colour'},
          'absolutey'  => 1
        }));
      } elsif($tag->{'style'} eq 'join') { 
        my $A = $strand > 0 ? 1 : 0;
        $self->join_tag( $composite, $tag->{'tag'}, $A, $A , $tag->{'colour'}, 'fill', $tag->{'zindex'} || -10 ),
        $self->join_tag( $composite, $tag->{'tag'}, 1-$A, $A , $tag->{'colour'}, 'fill', $tag->{'zindex'} || -10 )
      }
    }

    if( $style =~ /^mark_/ ) {
      my $bcol = 'red';
      if( $style =~ /_exonstart/ ) {
        $composite->push($self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'z'          => 10,
          'width'      => 1,
          'height'     => 0,
          "colour"     => $bcol,
          'absolutey'  => 1,
          'absolutez'  => 1
        }),$self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'z'          => 10,
          'width'      => 0,
          'height'     => $th,
          "colour"     => $bcol,
          'absolutey'  => 1,
          'absolutez'  => 1
        }));
      } elsif( $style =~ /_exonend/ ) {
        $composite->push( $self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'z'          => 10,
          'width'      => 1,
          'height'     => 0,
          "colour" => $bcol,
          'absolutey'  => 1,
          'absolutez' => 1
        }),$self->Rect({
          'x'          => ($start-1/$pix_per_bp),
          'y'          => 1,
          'z'          => 10,
          'width'      => 1/(2*$pix_per_bp),
          'height'     => $th,
          "colour" => $bcol,
          'absolutey'  => 1,
          'absolutez' => 1
        }));
      } elsif( $style =~ /_rexonstart/ ) {
        $composite->push( $self->Rect({
          'x'          => $start-1,
          'y'          => $th+1,
          'z'          => 10,
          'width'      => 1,
          'height'     => 0,
          "colour" => $bcol,
          'absolutey'  => 1,
          'absolutez' => 1
        }),$self->Rect({
          'x'          => $start-1,
          'y'          => 1,
          'z'          => 10,
          'width'      => 0,
          'height'     => $th,
          "colour" => $bcol,
          'absolutey'  => 1,
          'absolutez' => 1
        }) );
      } elsif( $style =~ /_rexonend/ ) {
        $composite->push( $self->Rect({
          'x'          => $start-1,
          'y'          => $th+1,
          'z'          => 10,
          'width'      => 1,
          'height'     => 0,
          "colour" => $bcol,
          'absolutey'  => 1,
          'absolutez' => 1
        }),$self->Rect({
          'x'          => ($start-1/$pix_per_bp),
          'y'          => 1,
          'z'          => 10,
          'width'      => 1/($pix_per_bp*2),
          'height'     => $th,
          "colour" => $bcol,
          'absolutey'  => 1,
          'absolutez' => 1
        }) );
      }
      if( $style =~ /_snpA/ ) {
        $composite->push ($self->Poly({
          'points'    => [ $start-1, 0,
                           $end+1, 0,
                           $end+1, $th  ],
          'colour'    => 'brown',
          'bordercolour'=>'red',
          'absolutey' => 1,
        }));
      }

      if($bp_textwidth < ($end - $start+1)){
        # print STDERR "X: $label - $colours->{'label'}\n";
        my $tglyph = $self->Text({
          'x'          => $start - 1,
          'y'          => ($h-$H)/2,
          'z' => 5,
          'width'      => $end-$start+1,
          'height'     => $H,
          'font'       => $FONT,
          'ptsize'     => $FONTSIZE,
          'halign'     => 'center',
          'colour'     => $colours->{'label'},
          'text'       => $label,
          'textwidth'  => $bp_textwidth*$pix_per_bp,
          'absolutey'  => 1,
          'absolutez'  => 1,
        });
        $composite->push($tglyph);
      }
    } elsif( $style && $label ) {
      if( $style eq 'overlaid' ) {
        if($bp_textwidth < ($end - $start+1)){
          # print STDERR "X: $label - $colours->{'label'}\n";
          $composite->push($self->Text({
            'x'          => $start-1,
            'y'          => ($h-$H)/2-1,
            'width'      => $end-$start+1,
            'textwidth'  => $bp_textwidth*$pix_per_bp,
            'font'       => $FONT,
            'ptsize'     => $FONTSIZE,
            'halign'     => 'center',
            'height'     => $H,
            'colour'     => $colours->{'label'},
            'text'       => $label,
            'absolutey'  => 1,
          }));
        }
      } else {
        my $label_strand = $self->my_config('label_strand');
        unless( $label_strand eq 'r' && $strand != -1 || $label_strand eq 'f' && $strand != 1 ) {
          $rowheight += $H+2;
          my $t = $self->Composite();
          $t->push($composite,$self->Text({
            'x'          => $start - 1,
            'y'          => $strand < 0 ? $h+3 : 3+$h,
            'width'      => $bp_textwidth,
            'height'     => $H,
            'font'       => $FONT,
            'ptsize'     => $FONTSIZE,
            'halign'     => 'left',
            'colour'     => $colours->{'label'},
            'text'       => $label,
            'absolutey'  => 1,
          }));
          $composite = $t;
	}
      }
    }

    ## Lets see if we can Show navigation ?...
    if($navigation) {
      $composite->{'title'} = $self->title( $f ) if $self->can('title');
      $composite->{'href'}  = $self->href(  $f ) if $self->can('href');
    }
    
    ## Are we going to bump ?
    if($row>0) {
      $composite->y( $composite->y() - $row * $rowheight * $strand );
      foreach(@tag_glyphs) {
        $_->y_transform( - $row * $rowheight * $strand );
      }
    }
    $C1++;
    $self->push( $composite );
    $self->push(@tag_glyphs);

    $self->highlight($f, $composite, $pix_per_bp, $h, 'highlight1');
  }
  # warn( ref($self)," $C1 out of $C out of $T features drawn\n" );
  ## No features show "empty track line" if option set....  ##
  $self->no_features() if $flag; 
}

sub highlight {
  my $self = shift;
  my ($f, $composite, $pix_per_bp, $h) = @_;

  ## Get highlights...
  my %highlights;
  @highlights{$self->highlights()} = ();

  ## Are we going to highlight this item...
  if($f->can('display_name') && exists $highlights{$f->display_name()}) {
    $self->unshift($self->Rect({
      'x'         => $composite->x() - 1/$pix_per_bp,
      'y'         => $composite->y() - 1,
      'width'     => $composite->width() + 2/$pix_per_bp,
      'height'    => $h + 2,
      'colour'    => 'highlight1',
      'absolutey' => 1,
    }));
  }
}

1;
