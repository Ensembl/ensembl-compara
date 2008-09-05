package Bio::EnsEMBL::GlyphSet_simple;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

use Sanger::Graphics::Bump;


sub features {
  return [];
} 

sub colour_key {
  return 'default';
}

sub feature_label {
  return ('','none');
}

sub title {
  return;
}

sub href {
  return;
}
sub tag {
  return;
}

use Bio::EnsEMBL::Feature;

sub aggregate_coverage {
  my( $self, $features ) = @_; 
  my $Config     = $self->{'config'};
  my $LN         = $Config->length();
  my $pix_per_bp = $Config->transform()->{'scalex'};
  my $BINS       = int($LN * $pix_per_bp / 4 );
  my $BL         = int($LN/$BINS);
  my $string     = '0' x ($LN+1);
  foreach my $f (@$features) {
         my $s = $f->start();
    next if $s > $LN;           ## Skip if totally outside VC
            $s = 1 if $s < 1;
         my $e = $f->end();
    next if $e < 1;             ## Skip if totally outside VC
            $e = $LN if $e>$LN;
    substr( $string,$s,$e ) = '1' x ($e-$s+1);
  }
  my $new_features = [];
  for(my  $bs = 1; $bs <= $LN; $bs+=$BL ) {
    my $count = (my $T =substr($string,$bs,$bs+$BL-1)) =~ tr/1/1/; 
    push @$new_features, {
      Bio::EnsEMBL::Feature->new(
        -start   => $bs
        -end     => $bs+$BL-1,
        -strand  => 1,
        -seqname => sprintf( "Coverage %0.1f%%", ($count/length($T) * 100) )
      )
    };
  }
  return $new_features;
}

sub _init {
  my ($self) = @_;
  my $slice   = $self->{'container'};
  $self->_threshold_update();
  my $strand          = $self->strand();
  my $strand_flag     = $self->my_config( 'strand' );
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
    $self->errorTrack( $self->my_label." only displayed for less than $max_length Kb.");
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
  $self->_init_bump( $dep );

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
  
  my $features = $self->features(); 

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
      $img_start = 0 if $img_start < 0;
      $img_end   = $BUMP_WIDTH + int( $img_end * $pix_per_bp );
      $img_end   = $bitmap_length if $img_end > $bitmap_length;
      $img_end   = $img_start if $img_end < $img_start;
      $row = $self->bump_row( $img_start, $img_end );
      next if $row > $dep;
    }
    my @tag_glyphs = ();

    my $colour_key     = $self->colour_key( $f );
    my $feature_colour = $self->my_colour( $colour_key );
    my $label_colour   = $self->my_colour( $colour_key, 'label' );
    my $part_to_colour = $self->my_colour( $colour_key, 'style' );
    # warn "$colour_key - $feature_colour, $label_colour";
    
    ## Lets see about placing labels on objects...        
    my $composite = $self->Composite();
    if($part_to_colour eq 'line') {
      #    print STDERR "PUSHING LINE\n"; 
      $composite->push( $self->Space({
        'x'          => $start-1,
        'y'          => 0,
        'width'      => $end - $start + 1,
        'height'     => $h,
        "colour"     => $feature_colour,
        'absolutey'  => 1
                               }));
      $composite->push( $self->Rect({
        'x'          => $start-1,
        'y'          => $h/2+1,
        'width'      => $end - $start + 1,
        'height'     => 0,
        "colour"     => $feature_colour,
        'absolutey'  => 1
      }));
    } elsif( $part_to_colour eq 'invisible' ) {
      $composite->push( $self->Space({
        'x'          => $start-1,
        'y'          => 0,
        'width'      => $end - $start + 1,
        'height'     => $h,
        'absolutey'  => 1
      }) );
    } elsif( $part_to_colour eq 'align' ) {
      $composite->push( $self->Rect({
          'x'          => $start-1,
          'y'          => 0,
          'z' => 20,
          'width'      => $end - $start + 1,
          'height'     => $h+2,
          "colour" => $feature_colour,
         'absolutey'  => 1,
          'absolutez'  => 1,
      }) );
    } else {
      $composite->push( $self->Rect({
        'x'          => $start-1,
        'y'          => 0,
        'width'      => $end - $start + 1,
        'height'     => $h,
        $part_to_colour."colour" => $feature_colour,
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
        # print STDERR "X: $label - $label_colour\n";
        my $tglyph = $self->Text({
          'x'          => $start - 1,
          'y'          => ($h-$H)/2,
          'z' => 5,
          'width'      => $end-$start+1,
          'height'     => $H,
         'font'       => $FONT,
          'ptsize'     => $FONTSIZE,
          'halign'     => 'center',
          'colour'     => $label_colour,
          'text'       => $label,
          'textwidth'  => $bp_textwidth*$pix_per_bp,
          'absolutey'  => 1,
          'absolutez'  => 1,
        });
        $composite->push($tglyph);
      }
    } elsif( $style ) {
      if( $style eq 'overlaid' ) {
        if($bp_textwidth < ($end - $start+1)){
          # print STDERR "X: $label - $label_colour\n";
          $composite->push($self->Text({
            'x'          => $start-1,
            'y'          => ($h-$H)/2-1,
            'width'      => $end-$start+1,
            'textwidth'  => $bp_textwidth*$pix_per_bp,
            'font'       => $FONT,
            'ptsize'     => $FONTSIZE,
            'halign'     => 'center',
            'height'     => $H,
            'colour'     => $label_colour,
            'text'       => $label,
            'absolutey'  => 1,
          }));
        }
      } else {
        my $label_strand = $self->my_config('label_strand');
        unless( $label_strand eq 'r' && $strand != -1 ||
	        $label_strand eq 'f' && $strand != 1 ) {
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
            'colour'     => $label_colour,
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

    my $hi_colour = 'highlight1';
    $self->highlight($f, $composite, $pix_per_bp, $h, $hi_colour);
  }
  # warn( ref($self)," $C1 out of $C out of $T features drawn\n" );
  ## No features show "empty track line" if option set....  ##
  $self->no_features() if $flag; 
}

sub highlight {
  my $self = shift;
  my ($f, $composite, $pix_per_bp, $h, $hi_colour) = @_;

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
      'colour'    => $hi_colour,
      'absolutey' => 1,
    }));
  }
}

1;
