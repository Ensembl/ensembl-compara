#########
# Author:        js5
# Last Modified: $Date$ $Author$
# Id:            $Id$
# Source:        $Source$
# $HeadURL$
#
package Bio::EnsEMBL::GlyphSet::Videogram;
use strict;
use warnings;
use base qw(Bio::EnsEMBL::GlyphSet::Videogram_legend);
use Sanger::Graphics::Bump;
use Carp;

our $VERSION = do { my @r = (q$Revision$ =~ /\d+/mxg); sprintf '%d.'.'%03d' x $#r, @r };

our $COL = {
	    'gpos100' => 'black',
	    'tip'     => 'slategrey',
	    'gpos75'  => 'grey40',
	    'gpos66'  => 'grey50',
	    'gpos50'  => 'grey60',
	    'gpos33'  => 'grey75',
	    'gpos25'  => 'grey85',
	    'gpos'    => 'black',
	    'gvar'    => 'grey88',
	    'gneg'    => 'white',
	    'acen'    => 'slategrey',
	    'stalk'   => 'slategrey',
     };


####################################################################
### set true only while you're generating the vega karyotype image ##
#####################################################################
  if (0) {
     $COL->{'gpos100'}        = 'darkslategray';
     $COL->{'gpos75'}         = 'cadetblue2';
     $COL->{'gpos66'}         = 'cadetblue2';
     $COL->{'gpos50'}         = 'cadetblue3';
     $COL->{'gpos33'}         = 'cadetblue4';
     $COL->{'gpos25'}         = 'cadetblue4';
     $COL->{'gpos'}           = 'darkslategray';
     $COL->{'gvar'}           = 'darkslategray3';
     $COL->{'gneg'}           = 'white';
     $COL->{'acen'}           = 'darkslategray4';
     $COL->{'stalk'}          = 'darkslategray4';
     $COL->{'NoAnnotation'}   = 'gray75'; # marks start/end of unannotated sequence
     $COL->{'CORFAnnotation'} = 'gray90'; # marks start/end of CORF project annotated sequence
  }
## end of vega karyotype static image colours ###                                                

sub _init {
  my ($self) = @_;
  my $config = $self->{'config'};

  if(!$config->container_width()) {
    #########
    # The container has zero width !!EXIT!!
    #
    return;
  }

  my $col   = undef;
  my $white = 'white';
  my $black = 'black';
  my $bg    = $config->get_parameter( 'bgcolor');
  my $red   = 'red';

  $self->{'pix_per_bp'}     = $config->image_width() / $config->container_width();
  $self->{'bitmap_length'}  = $config->image_width();
  $self->{'reverse_bitmap'} = [];
  $self->{'forward_bitmap'} = [];


  my $im_width    = $config->image_width();
  my $top_margin  = $config->{'_top_margin'};
  my ($w,$h)      = $config->texthelper->Vpx2bp('Tiny');
  my $chr         = $self->{'container'}->{'chr'} || $self->{'extras'}->{'chr'};

  #########
  # fetch the chromosome bands that cover this VC.
  #
  my $kba           = $self->{'container'}->{'ka'};
  my $bands         = $kba->fetch_all_by_chr_name($chr);
  my $slice_adaptor = $self->{'container'}->{'sa'};
  my $slice         = $slice_adaptor->fetch_by_region(undef, $chr) or
    (carp "$slice_adaptor has no fetch_by_region(undef,$chr)" && return);

  my $chr_length = $slice->length || 1;

  #########
  # bottom align each chromosome!
  #
  my $v_offset    = $config->container_width() - $chr_length;
  my $bpperpx     = $config->container_width()/$config->{'_image_height'};

  #########
  # overcome a bottom border/margin problem....
  #
  my $done_1_acen = 0;        # flag for tracking place in chromosome
  my $wid         = $config->get('Videogram', 'width');
  my $h_wid       = int $wid/2;
  my $padding     = $config->get('Videogram', 'padding') || 6;
  my $style       = $config->get('Videogram', 'style')   || q();
  my $h_offset;

  #########
  # get text labels in correct place!
  #
  if ($style eq 'text') {
    $h_offset = $padding;

  } else {
    #########
    # max width of band label is 6 characters
    #
    $h_offset    = int($self->{'config'}->get('Videogram', 'totalwidth')
		       - $wid
		       - ($self->{'config'}->{'_band_labels'} eq 'on' ? ($w * 6 + 4) : 0 )
		      )/2;
  }

  my @decorations;

  if($padding) {
    #########
    # make sure that there is a blank image behind the chromosome so that the
    # glyphset doesn't get "horizontally" squashed.
    #
    $self->push(Sanger::Graphics::Glyph::Space->new({
						     'x'         => 0,
						     'y'         => $h_offset - $padding,
						     'width'     => 10_000,
						     'height'    => $padding * 2 + $wid,
						     'absolutey' => 1,
						    }));
  }

  my @bands = sort { $a->start <=> $b->start } @{$bands};
  #########
  # use this array to store bands created for vega annotation status; draw these last
  #
  my @annot_bands;

  if(scalar @bands) {
    for my $band (@bands) {
      my $bandname       = $band->name();
      my $vc_band_start  = $band->start() + $v_offset;
      my $vc_band_end    = $band->end() + $v_offset;
      my $stain          = $band->stain();

      if ($stain =~ /Annotation/mx) {
	push @annot_bands, $band;
	next;
      }

      my $HREF;
      if($self->{'config'}->{'_band_links'}) {
	$HREF = "/@{[$self->{container}{web_species}]}/contigview?chr=$chr;vc_start=$vc_band_start;vc_end=$vc_band_end";
      }

      if ($stain eq 'acen') {
	my $gband;
	if ($done_1_acen) {
	  $gband = $self->Poly({
			       'points'    => [
					       $vc_band_start, $h_offset + $h_wid,
					       $vc_band_end,   $h_offset,
					       $vc_band_end,   $h_offset + $wid,
					      ],
			       'colour'    => $COL->{$stain},
			       'absolutey' => 1,
			       'href'      => $HREF,
			      });
	} else {
	  $gband = $self->Poly({
			       'points'    => [
					       $vc_band_start, $h_offset,
					       $vc_band_end,   $h_offset + $h_wid,
					       $vc_band_start, $h_offset + $wid,
					      ],
			       'colour'    => $COL->{$stain},
			       'absolutey' => 1,
			       'href'      => $HREF,
			      });
	  $done_1_acen = 1;
	}
	push @decorations, $gband;

      } elsif ($stain eq 'stalk') {
	push @decorations, $self->Poly({
				       'points'    => [
						       $vc_band_start, $h_offset,
						       $vc_band_end,   $h_offset + $wid,
						       $vc_band_end,   $h_offset,
						       $vc_band_start, $h_offset + $wid,
						      ],
				       'colour'    => $COL->{$stain},
				       'absolutey' => 1,
				       'href'      => $HREF,
				      });

	push @decorations, $self->Rect({
				       'x'         => $vc_band_start,
				       'y'         => $h_offset    + int $wid/4,
				       'width'     => $vc_band_end - $vc_band_start,
				       'height'    => $h_wid,
				       'colour'    => $COL->{$stain},
				       'absolutey' => 1,
				       'href'      => $HREF,
				      });

      } else {
	if (($self->{'config'}->{'_hide_bands'} || 'no') eq 'yes') {
	  $stain = 'gneg';
	}

	my $R     = $vc_band_start;
	my $T     = $bpperpx * ( (int $vc_band_end/$bpperpx) - (int $vc_band_start/$bpperpx) );
	$self->push($self->Rect({
				'x'                => $R,
				'y'                => $h_offset,
				'width'            => $T,
				'height'           => $wid,
				'colour'           => $COL->{$stain},
				'absolutey'        => 1,
				'href'             => $HREF,
			       }));

	$self->push($self->Line({
				'x'                => $R,
				'y'                => $h_offset,
				'width'            => $T,
				'height'           => 0,
				'colour'           => $black,
				'absolutey'        => 1,
			       }));

	$self->push($self->Line({
				'x'                => $R,
				'y'                => $h_offset+$wid,
				'width'            => $T,
				'height'           => 0,
				'colour'           => $black,
				'absolutey'        => 1,
			       }));
      }

      #################################################################
      # only add the band label if the box is big enough to hold it...
      #################################################################
      if(!($stain eq 'acen'  ||
	   $stain eq 'tip'   ||
	   $stain eq 'stalk' ||
	   ($self->{'config'}->{'_band_labels'} ne 'on') ||
	   ($h > ($vc_band_end - $vc_band_start)))) {

	$self->push($self->Text({
				'x'                => ($vc_band_end + $vc_band_start - $h)/2,
				'y'                => $h_offset+$wid+4,
				'width'            => $h,
				'height'           => $w * length($bandname),
				'font'             => 'Tiny',
				'colour'           => $black,
				'text'             => $bandname,
				'absolutey'        => 1,
				'href'             => $HREF,
			       }));
      }
    }

  } else {
    foreach (0, $wid) {
      $self->push($self->Line({
			      'x'                => $v_offset-1,
			      'y'                => $h_offset+$_,
			      'width'            => $chr_length,
			      'height'           => 0,
			      'colour'           => $black,
			      'absolutey'        => 1,
			     }));
    }
  }

  #########
  # lastly draw annotation status bands (if uncommented the colour definition)
  #
  for my $band (@annot_bands) {
    my $bandname       = $band->name();
    my $vc_band_start  = $band->start() + $v_offset;
    my $vc_band_end    = $band->end() + $v_offset;
    my $stain          = $band->stain();
    my $R              = $vc_band_start;
    my $T              = $bpperpx * ( (int $vc_band_end/$bpperpx) - (int $vc_band_start/$bpperpx) );

    $self->push($self->Rect({
			    'x'                => $R,
			    'y'                => $h_offset,
			    'width'            => $T,
			    'height'           => $wid,
			    'colour'           => $COL->{$stain},
			    'absolutey'        => 1,
			   }));
    $self->push($self->Line({
			    'x'                => $R,
			    'y'                => $h_offset,
			    'width'            => $T,
			    'height'           => 0,
			    'colour'           => $black,
			    'absolutey'        => 1,
			   }));

    $self->push($self->Line({
			    'x'                => $R,
			    'y'                => $h_offset+$wid,
			    'width'            => $T,
			    'height'           => 0,
			    'colour'           => $black,
			    'absolutey'        => 1,
			   }));
  }

  foreach (@decorations) {
    $self->push($_);
  }

  ##############################################
  # Draw the ends of the ideogram
  ##############################################
  for my $end (
	       ( @bands && $bands[ 0]->stain() eq 'tip' ? () : 0 ),
	       ( @bands && $bands[-1]->stain() eq 'tip' ? () : 1 )
	      ) {
    my $direction   = $end ? -1 : 1;
    my %partials    = map { uc($_) => 1 } @{ $self->species_defs->PARTIAL_CHROMOSOMES || [] };
    my %artificials = map { uc($_) => 1 } @{ $self->species_defs->ARTIFICIAL_CHROMOSOMES || [] };

    if ($partials{uc $chr}) {
      #########
      # draw jagged ends for partial chromosomes
      # resolution dependent scaling
      #
      my $mod = ($wid < 16) ? 0.5 : 1;

      for my $i (1..8*$mod) {
	my $x      = $v_offset + $chr_length * $end - 4 * (($i % 2) - 1) * $direction * $bpperpx * $mod;
	my $y      = $h_offset + $wid/(8*$mod) * ($i - 1);
	my $width  = 4 * (-1 + 2 * ($i % 2)) * $direction * $bpperpx * $mod;
	my $height = $wid/(8*$mod);

	#########
	# overwrite karyotype bands with appropriate triangles to produce jags
	#
	$self->push($self->Poly({
				'points'         => [
						     $x, $y,
						     $x + $width * (1 - ($i % 2)),$y + $height * ($i % 2),
						     $x + $width, $y + $height,
						    ],
				'colour'         => $bg,
				'absolutey'      => 1,
				'absoluteheight' => 1,
			       }));

	#########
	# the actual jagged line
	#
	$self->push($self->Line({
				'x'              => $x,
				'y'              => $y,
				'width'          => $width,
				'height'         => $height,
				'colour'         => $black,
				'absolutey'      => 1,
				'absoluteheight' => 1,
			       }));
      }

      #########
      # black delimiting lines at each side
      #
      foreach (0, $wid) {
	$self->push($self->Line({
				'x'             => $v_offset,
				'y'             => $h_offset + $_,
				'width'         => 4,
				'height'        => 0,
				'colour'        => $black,
				'absolutey'     => 1,
				'absolutewidth' => 1,
			       }));
      }

    } elsif ( ($artificials{uc($chr)}) ||
	      ($end == 0 && @bands && $bands[0]->stain()  eq 'ACEN') ||
	      ($end == 1 && @bands && $bands[-1]->stain() eq 'ACEN') ||
	      ($end == 0 && $chr =~ /Q|q/mx) ||
	      ($end == 1 && $chr =~ /P|p/mx)
	    ) {
      #########
      # draw blunt ends for artificial chromosomes or chr arms
      #
      my $x      = $v_offset + $chr_length * $end - 1;
      my $y      = $h_offset;
      my $width  = 0;
      my $height = $wid;

      $self->push($self->Line({
			      'x'             => $x,
			      'y'             => $y,
			      'width'         => $width,
			      'height'        => $height,
			      'colour'        => $black,
			      'absolutey'     => 1,
			      'absolutewidth' => 1,
			     }));

    } else {
      #########
      # round ends for full chromosomes
      #
      my $max_rows = ( $chr_length / $bpperpx /2 ); ## MAXIMUMROWS.....

      my @lines = $wid < 16 ?
	          ( [8,6],[4,4],[2,2] ) :
	          ( [8,5],[5,3],[4,1],[3,1],[2,1],[1,1],[1,1],[1,1] );

      for my $I ( 0..$#lines ) {
	if($I > $max_rows) {
	  next;
	}

	my ($bg_x, $black_x) = @{$lines[$I]};
	my $xx               = $v_offset + $chr_length * $end + ($I+.5 * $end) * $direction * $bpperpx + ($end ? $bpperpx : 10);
	$self->push($self->Line({
				'x'         => $xx,
				'y'         => $h_offset,
				'width'     => 0,
				'height'    => $wid * $bg_x/24 -1,
				'colour'    => $bg,
				'absolutey' => 1,
			       }));
	$self->push($self->Line({
				'x'         => $xx,
				'y'         => $h_offset + 1 + $wid * (1-$bg_x/24),
				'width'     => 0,
				'height'    => $wid * $bg_x/24 -1,
				'colour'    => $bg,
				'absolutey' => 1,
			       }));

	$self->push($self->Line({
				'x'         => $xx,
				'y'         => $h_offset + $wid * $bg_x/24,
				'width'     => 0,
				'height'    => $wid * $black_x/24 -1,
				'colour'    => $black,
				'absolutey' => 1,
			       }));

	$self->push($self->Line({
				'x'         => $xx,
				'y'         => $h_offset + 1 + $wid * (1-$bg_x/24-$black_x/24),
				'width'     => 0,
				'height'    => $wid * $black_x/24 -1,
				'colour'    => $black,
				'absolutey' => 1,
			       }));
      }
    }
  }

  #######################################
  # Do the highlighting bit at the end!!!
  #######################################
  if(defined $self->{'highlights'} && $self->{'highlights'} ne q()) {
    for my $highlight_set (reverse @{$self->{'highlights'}}) {
      my $highlight_style = $style || $highlight_set->{'style'};
      my $type            = "highlight_$highlight_style";
      my $aggregate_colour = $config->{'_aggregate_colour'};

      if($highlight_set->{$chr}) {
	      # Firstly create a highlights array which contains merged entries!
	      my @temp_highlights = @{$highlight_set->{$chr}};
	      my @highlights;

	      if($highlight_set->{'merge'} && $highlight_set->{'merge'} eq 'no') {
	        @highlights = @temp_highlights;
	      } 
        else {
	        my @bin_flag;
	        my $bin_length = $padding * ( $highlight_style eq 'arrow' ? 1.5 : 1 ) * $bpperpx;

          my $is_aggregated = 0;
	        foreach (@temp_highlights) {
	          my $bin_id = int (2 * $v_offset+ $_->{'start'}+$_->{'end'}) / 2 / $bin_length;
	          if ($bin_id < 0) {
	            $bin_id = 0;
	          }

	          if(my $offset = $bin_flag[$bin_id]) { # We already have a highlight in this bin - so add this one to it!

              ## Build zmenu
	            my $zmenu_length = keys %{$highlights[$offset-1]->{'zmenu'}};
	            for my $entry (sort keys %{$_->{'zmenu'}}) {
		            if($entry eq 'caption') {
		              next;
		            }

		            my $value = $_->{'zmenu'}->{$entry};
		            $entry    =~ s/\d\d+://mx;

		            $highlights[$offset-1]->{'zmenu'}->{ sprintf q(%03d:%s), $zmenu_length++, $entry } = $value;

		            if ($highlights[$offset-1]->{'start'} > $_->{'start'}) {
		              $highlights[$offset-1]->{'start'} = $_->{'start'};
		            }

		            if ($highlights[$offset-1]->{'end'} < $_->{'end'}) {
		              $highlights[$offset-1]->{'end'}   = $_->{'end'};
		            }
	            }

              ## Deal with colour aggregation
              if ($_->{'col'} eq $aggregate_colour) {
                $is_aggregated = 1;
              }
              if ($is_aggregated) {
                $highlights[$offset-1]->{'col'} = $aggregate_colour;
              }
	          } 
            else { # We don't
	            push @highlights, $_;
	            $bin_flag[$bin_id] = @highlights;
              $is_aggregated = 0;
	          }
	        }
	      }

	#########
	# Now we render the points
	#
	      my $high_flag    = 'l';
	      my @starts       = map { $_->{'start'} } @highlights;
	      my @sorting_keys = sort { $starts[$a] <=> $starts[$b] } 0..$#starts;
	      my @flags        = ();
	      my $flag         = 'l';

	      foreach (@sorting_keys) {
	        $flags[$_] = $flag = $flag eq 'l' ? 'r' : 'l';
	      }

	      foreach (@highlights) {
	        my $start = $v_offset + $_->{'start'};
	        my $end   = $v_offset + $_->{'end'};

	        if ($highlight_style eq 'arrow') {
	          $high_flag = shift @flags;
	          $type      = "highlight_${high_flag}h$highlight_style";
	        }

	        my $zmenu = $_->{'zmenu'};
	        my $col   = $_->{'col'};

	  #########
	  # dynamic require of the right type of renderer
	  #
	        if($self->can($type)) {
	          my $g = $self->$type( {
				              'chr'       => $chr,
				              'start'     => $start,
				              'end'       => $end,
				              'mid'       => ($start+$end)/2,
				              'h_offset'  => $h_offset,
				              'wid'       => $wid,
				              'padding'   => $padding,
				              'padding2'  => $padding * $bpperpx * sqrt(3)/2,
				              'zmenu'     => $zmenu,
				              'col'       => $col,
				              'id'        => $_->{'id'},
				              'strand'    => $_->{'strand'},
				            } );
	          $g and $self->push($g);
	        }
	      }
      }
    }
  }
  $self->minx( $v_offset );
  return;
}

1;
