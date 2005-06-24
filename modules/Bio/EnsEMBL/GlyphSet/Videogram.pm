#########
# Author: js5
#
package Bio::EnsEMBL::GlyphSet::Videogram;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Glyph::Space;
use Sanger::Graphics::Bump;

use SpeciesDefs;
my $species_defs = SpeciesDefs->new();


sub init_label {
    my $self = shift;
    return if( $self->{'config'}->{'_label'} eq 'none'  );
    
    my $chr = $self->{'container'}->{'chr'} || $self->{'extras'}->{'chr'};
    $chr = uc($chr) unless ($self->{'config'}->{'_uppercase_label'} eq 'no');
    
    # two-line label for long chromosome names
    if (length($chr) > 4 && $self->{'config'}->{'_label'} eq 'above' ) {
        my $label = new Sanger::Graphics::Glyph::Text({
            'text'      => 'Chromosome',
            'font'      => 'Small',
            'absolutey' => 1,
        });
        $self->label($label);
        my $label2 = new Sanger::Graphics::Glyph::Text({
            'text'      => $chr,
            'font'      => 'Small',
            'absolutey' => 1,
        });
        $self->label2($label2);
    } else {
        $chr = "Chromosome $chr" if( $self->{'config'}->{'_label'} eq 'above' );
        my $label = new Sanger::Graphics::Glyph::Text({
            'text'      => $chr,
            'font'      => 'Small',
            'absolutey' => 1,
        });
        $self->label($label);
    }
}

sub _init {
    my ($self) = @_;

    my $Config = $self->{'config'};
    return unless $Config->container_width()>0; # The container has zero width !!EXIT!!
    
    my $col    = undef;
    my $cmap   = $Config->colourmap();
    my $white  = 'white';
    my $black  = 'black';
    my $bg     = $Config->get('_settings','bgcolor');
    my $red    = 'red';

    $self->{'pix_per_bp'}     = $Config->image_width() / $Config->container_width();
    $self->{'bitmap_length'}  = $Config->image_width();
    $self->{'reverse_bitmap'} = [];
    $self->{'forward_bitmap'} = [];

    my %COL = ();
    $COL{'gpos100'} = 'black'; #add_rgb([200,200,200]);
    $COL{'tip'}     = 'slategrey';
    $COL{'gpos75'}  = 'grey40'; #add_rgb([210,210,210]);
    $COL{'gpos50'}  = 'grey60'; #add_rgb([230,230,230]);
    $COL{'gpos25'}  = 'grey85'; #add_rgb([240,240,240]);
    $COL{'gpos'}    = 'black'; #add_rgb([240,240,240]);
    $COL{'gvar'}    = 'grey88'; #add_rgb([222,220,220]);
    $COL{'gneg'}    = 'white';
    $COL{'acen'}    = 'slategrey';
    $COL{'stalk'}   = 'slategrey';
    $COL{'mark'}    = 'blue'; # marks start/end of annotated sequence

    my $im_width    = $Config->image_width();
    my $top_margin  = $Config->{'_top_margin'};
    my ($w,$h)      = $Config->texthelper->Vpx2bp('Tiny');
    my $chr         = $self->{'container'}->{'chr'} || $self->{'extras'}->{'chr'};

    # fetch the chromosome bands that cover this VC.
    my $kba         = $self->{'container'}->{'ka'};
    my $bands       = $kba->fetch_all_by_chr_name($chr);

    my $slice_adaptor = $self->{'container'}->{'sa'};
    my $slice = $slice_adaptor->fetch_by_region('chromosome',$chr) ||
      (warn("$slice_adaptor has no fetch_by_region('chromosome',$chr)" ) && return);
    my $chr_length = $slice->length || 1;
    # bottom align each chromosome!
    my $v_offset    = $Config->container_width() - $chr_length; 
    my $bpperpx     = $Config->container_width()/$Config->{'_image_height'};
    # overcome a bottom border/margin problem....

    my $done_1_acen = 0;        # flag for tracking place in chromsome
    my $wid         = $Config->get('Videogram','width');
    my $h_wid       = int($wid/2);
    my $padding     = $Config->get('Videogram','padding') || 6;

    my $style       = $Config->get('Videogram', 'style');
    
    my $h_offset;
    # get text labels in correct place!
    if ($style eq 'text') {
        $h_offset = $padding;
    }
    else {
        # max width of band label is 6 characters
        $h_offset    = int($self->{'config'}->get('Videogram', 'totalwidth') 
                            - $wid
                            - ($self->{'config'}->{'_band_labels'} eq 'on' ? ($w * 6 + 4) : 0 )
                            )/2;
    }

    my @decorations;

    if($padding) {
    # make sure that there is a blank image behind the chromosome so that the
    # glyphset doesn't get "horizontally" squashed.
   
        my $gpadding = new Sanger::Graphics::Glyph::Space({
            'x'         => 0,
            'y'         => $h_offset - $padding,
            'width'     => 10000,
            'height'    => $padding * 2 + $wid,
            'absolutey' => 1,
        });
        $self->push($gpadding);        
    }
    my @bands =  sort{$a->start <=> $b->start } @$bands;
    if( @bands ) {
      foreach my $band (@bands){
        my $bandname       = $band->name();
        my $vc_band_start  = $band->start() + $v_offset;
        my $vc_band_end    = $band->end() + $v_offset;
        my $stain          = $band->stain();

        my $HREF;
        if($self->{'config'}->{'_band_links'}) {
            $HREF = "/@{[$self->{container}{_config_file_name_}]}/contigview?chr=$chr;vc_start=$vc_band_start;vc_end=$vc_band_end";
        }
        if ($stain eq "acen"){
            my $gband;
            if ($done_1_acen){
                $gband = new Sanger::Graphics::Glyph::Poly({
                    'points'       => [ 
                                        $vc_band_start,$h_offset + $h_wid, 
                                        $vc_band_end,$h_offset,
                                        $vc_band_end,$h_offset + $wid,
                                      ],
                    'colour'       => $COL{$stain},
                    'absolutey'    => 1,
                    'href'         => $HREF
                });
            } else {
                $gband = new Sanger::Graphics::Glyph::Poly({
                    'points'       => [ 
                                        $vc_band_start,$h_offset, 
                                        $vc_band_end,$h_offset + $h_wid,
                                        $vc_band_start,$h_offset + $wid,
                                      ],
                    'colour'       => $COL{$stain},
                    'absolutey'    => 1,
                    'href'         => $HREF
                });
                $done_1_acen = 1;
            }
            push @decorations, $gband;
        } elsif ($stain eq "stalk"){
            my $gband = new Sanger::Graphics::Glyph::Poly({
                'points'           => [
                                        $vc_band_start,$h_offset, 
                                        $vc_band_end,$h_offset + $wid,
                                        $vc_band_end,$h_offset,
                                        $vc_band_start,$h_offset + $wid, 
                                      ],
                'colour'           => $COL{$stain},
                'absolutey'        => 1,
                'href'             => $HREF
            });
            push @decorations, $gband;
            $gband = new Sanger::Graphics::Glyph::Rect({
                'x'                => $vc_band_start,
                'y'                => $h_offset+ int($wid/4),
                'width'            => $vc_band_end - $vc_band_start,
                'height'           => $h_wid,
                'colour'           => $COL{$stain},
                'absolutey'        => 1,
                'href'             => $HREF
            });
            push @decorations, $gband;
        } else {
            $stain = 'gneg' if(($self->{'config'}->{'_hide_bands'}||"no") eq 'yes' );
            my $R = $vc_band_start;
            my $T = $bpperpx * ( int($vc_band_end/$bpperpx) - int($vc_band_start/$bpperpx) );
            my $gband = new Sanger::Graphics::Glyph::Rect({
                'x'                => $R,
                'y'                => $h_offset,
                'width'            => $T,
                'height'           => $wid,
                'colour'           => $COL{$stain},
                'absolutey'        => 1,
                'href'             => $HREF
            });
            $self->push($gband);
            $gband = new Sanger::Graphics::Glyph::Line({
                'x'                => $R,
                'y'                => $h_offset,
                'width'            => $T,
                'height'           => 0,
                'colour'           => $black,
                'absolutey'        => 1,
            });
            $self->push($gband);
            $gband = new Sanger::Graphics::Glyph::Line({
                'x'                => $R,
                'y'                => $h_offset+$wid,
                'width'            => $T,
                'height'           => 0,
                'colour'           => $black,
                'absolutey'        => 1,
            });
            $self->push($gband);
        }
        my $fontcolour;

    #################################################################
    # only add the band label if the box is big enough to hold it...
    #################################################################
        unless (    $stain eq "acen" || $stain eq "tip" || $stain eq "stalk" ||
                    ($self->{'config'}->{'_band_labels'} ne 'on') ||
                    ($h > ($vc_band_end - $vc_band_start))
        ){
            my $tglyph = new Sanger::Graphics::Glyph::Text({
                'x'                => ($vc_band_end + $vc_band_start - $h)/2,
                'y'                => $h_offset+$wid+4,
                'width'            => $h,
                'height'           => $w * length($bandname),
                'font'             => 'Tiny',
                'colour'           => $black,
                'text'             => $bandname,
                'absolutey'        => 1,
                'href'             => $HREF        
            });
            $self->push($tglyph);
        }
      }
    } else {
      foreach (0,$wid) {
        $self->push(new Sanger::Graphics::Glyph::Line({
          'x'                => $v_offset-1,
          'y'                => $h_offset+$_,
          'width'            => $chr_length,
          'height'           => 0,
          'colour'           => $black,
          'absolutey'        => 1,
        }));
      }
    }

    foreach( @decorations ) {
        $self->push($_);
    }
    ##############################################
    # Draw the ends of the ideogram
    ##############################################
    foreach my $end ( 
        ( @bands && $bands[ 0]->stain() eq 'tip' ? () : 0 ),
        ( @bands && $bands[-1]->stain() eq 'tip' ? () : 1 )
     ) {
        my $direction = $end ? -1 : 1;
        
        my %partials = map { uc($_) => 1 }
        	@{ $species_defs->PARTIAL_CHROMOSOMES || [] };
	my %artificials = map { uc($_) => 1 }
	        @{ $species_defs->ARTIFICIAL_CHROMOSOMES || [] };
        if ($partials{uc($chr)}) {
        # draw jagged ends for partial chromosomes
            # resolution dependent scaling
            my $mod = ($wid < 16) ? 0.5 : 1;
            foreach my $i (1..8*$mod) {
                my $x = $v_offset + $chr_length * $end - 4 * (($i % 2) - 1) * $direction * $bpperpx * $mod;
                my $y = $h_offset + $wid/(8*$mod) * ($i - 1);
                my $width = 4 * (-1 + 2 * ($i % 2)) * $direction * $bpperpx * $mod;
                my $height = $wid/(8*$mod);
                # overwrite karyotype bands with appropriate triangles to
                # produce jags
                my $triangle = new Sanger::Graphics::Glyph::Poly({
                    'points'    => [
                        $x, $y,
                        $x + $width * (1 - ($i % 2)),$y + $height * ($i % 2),
                        $x + $width, $y + $height,
                    ],
                    'colour'    => $bg,
                    'absolutey' => 1,
                    'absoluteheight' => 1,
                });
                $self->push($triangle);
                # the actual jagged line
                my $glyph = new Sanger::Graphics::Glyph::Line({
                    'x'         => $x,
                    'y'         => $y,
                    'width'     => $width,
                    'height'    => $height,
                    'colour'    => $black,
                    'absolutey' => 1,
                    'absoluteheight' => 1,
                });
                $self->push($glyph);
            }
            # black delimiting lines at each side
            foreach (0, $wid) {
                $self->push(new Sanger::Graphics::Glyph::Line({
                    'x'                => $v_offset,
                    'y'                => $h_offset + $_,
                    'width'            => 4,
                    'height'           => 0,
                    'colour'           => $black,
                    'absolutey'        => 1,
                    'absolutewidth'    => 1,
                }));
            }
	} elsif ($artificials{uc($chr)}) {
        # draw blunt ends for artificial chromosomes
	    my $x = $v_offset + $chr_length * $end - 1;
	    my $y = $h_offset;
	    my $width = 0;
            my $height = $wid;
            my $glyph = new Sanger::Graphics::Glyph::Line({
                'x'      => $x,
                'y'      => $y,
                'width'  => $width,
                'height' => $height,
                'colour' => $black,
                'absolutey' => 1,
		'absolutewidth' => 1,
                });
            $self->push($glyph);
	} else {
        # round ends for full chromosomes
            my $max_rows = ( $chr_length / $bpperpx /2 ); ## MAXIMUMROWS.....
            my @lines = $wid < 16 ?
                ( [8,6],[4,4],[2,2] ) :
                ( [8,5],[5,3],[4,1],[3,1],[2,1],[1,1],[1,1],[1,1] ) ;
            foreach my $I ( 0..$#lines ) {
               next if $I > $max_rows;
                my ( $bg_x, $black_x ) = @{$lines[$I]};
                my $xx = $v_offset + $chr_length * $end + ($I+.5 * $end) * $direction * $bpperpx + ($end ? $bpperpx : 10);
                my $glyph = new Sanger::Graphics::Glyph::Line({
                    'x'         => $xx,
                    'y'         => $h_offset,
                    'width'     => 0,
                    'height'    => $wid * $bg_x/24 -1,
                    'colour'    => $bg,
                    'absolutey' => 1,
                });
                $self->push($glyph);
                $glyph = new Sanger::Graphics::Glyph::Line({
                    'x'         => $xx,
                    'y'         => $h_offset + 1 + $wid * (1-$bg_x/24),
                    'width'     => 0,
                    'height'    => $wid * $bg_x/24 -1 ,
                    'colour'    => $bg,
                    'absolutey' => 1,
                }) ;
                $self->push($glyph);
                $glyph = new Sanger::Graphics::Glyph::Line({
                    'x'         => $xx,
                    'y'         => $h_offset + $wid * $bg_x/24,
                    'width'     => 0,
                    'height'    => $wid * $black_x/24 -1 ,
                    'colour'    => $black,
                    'absolutey' => 1,
                });
                $self->push($glyph);
                $glyph = new Sanger::Graphics::Glyph::Line({
                    'x'         => $xx,
                    'y'         => $h_offset + 1 + $wid * (1-$bg_x/24-$black_x/24),
                    'width'     => 0,
                    'height'    => $wid * $black_x/24 -1 ,
                    'colour'    => $black,
                    'absolutey' => 1,
                });
                $self->push($glyph);
            }
        }
    }
    
    #######################################
    # Do the highlighting bit at the end!!!
    #######################################
    
    if(defined $self->{'highlights'}) {

    foreach my $highlight_set (reverse @{$self->{'highlights'}}) {
    my $highlight_style = $highlight_set->{'style'};
        my $type ="highlight_$highlight_style";
        
        if($highlight_set->{$chr}) {
# Firstly create a highlights array which contains merged entries!
            my @temp_highlights = @{$highlight_set->{$chr}};
            my @highlights;
            if($highlight_set->{'merge'} && $highlight_set->{'merge'} eq 'no') {
                @highlights = @temp_highlights;
            } else {
                my @bin_flag;
                my $bin_length = $padding * ( $highlight_style eq 'arrow' ? 1.5 : 1 ) * $bpperpx;
                foreach(@temp_highlights) {
                    my $bin_id = int( (2 * $v_offset+ $_->{'start'}+$_->{'end'}) / 2 / $bin_length );
                    $bin_id = 0 if $bin_id<0;
                    if(my $offset = $bin_flag[$bin_id]) { # We already have a highlight in this bin - so add this one to it!
                        my $zmenu_length = keys %{$highlights[$offset-1]->{'zmenu'}};
                        foreach my $entry (sort keys %{$_->{'zmenu'}}) { 
                            next if $entry eq 'caption';
                            my $value = $_->{'zmenu'}->{$entry};
                            $entry=~s/\d\d+://;
                            $highlights[$offset-1]->{'zmenu'}->{ sprintf("%03d:%s",$zmenu_length++,$entry) } = $value;
                            $highlights[$offset-1]->{'start'} = $_->{'start'} if ($highlights[$offset-1]->{'start'} > $_->{'start'});
                            $highlights[$offset-1]->{'end'} = $_->{'end'} if ($highlights[$offset-1]->{'end'} < $_->{'end'});
                        }
                    } else { # We don't
                        push @highlights, $_;
                        $bin_flag[$bin_id] = @highlights;
                    }
                }
                my @highlights = @highlights;
            }
# Now we render the points!
            my $high_flag = 'l';
            my @starts = map { $_->{'start'} } @highlights;
            my @sorting_keys = sort { $starts[$a] <=> $starts[$b] } 0..$#starts;
            my @flags = ();
            my $flag = 'l';
            foreach( @sorting_keys ) {
                $flags[$_] = $flag = $flag eq 'l' ? 'r' : 'l';
            }
            foreach( @highlights ) { 
                my $start     = $v_offset + $_->{'start'};
                my $end       = $v_offset + $_->{'end'};
                if( $highlight_style eq 'arrow' ) {
                    $high_flag = shift @flags;
                    $type      = "highlight_${high_flag}h$highlight_style";
                }
                my $zmenu     = $_->{'zmenu'};
                my $col       = $_->{'col'};
            ########## dynamic require of the right type of renderer
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
}

sub highlight_box {
    my $self = shift;
    my $details = shift;
    return new Sanger::Graphics::Glyph::Rect({
        'x'         => $details->{'start'},
        'y'         => $details->{'h_offset'},
        'width'     => $details->{'end'}-$details->{'start'},
        'height'    => $details->{'wid'},
        'colour'    => $details->{'col'},
        'absolutey' => 1,
        'zmenu'     => $details->{'zmenu'}
    });
}

sub highlight_filledwidebox {
    my $self = shift;
    my $details = shift;
    return new Sanger::Graphics::Glyph::Rect({
        'x'             => $details->{'start'},
        'y'             => $details->{'h_offset'}-$details->{'padding'},
        'width'         => $details->{'end'}-$details->{'start'},
        'height'        => $details->{'wid'}+$details->{'padding'}*2,
        'colour'        => $details->{'col'},
        'absolutey'     => 1,
        'zmenu'         => $details->{'zmenu'}
    });
}

sub highlight_widebox {
    my $self = shift;
    my $details = shift;
    return new Sanger::Graphics::Glyph::Rect({
        'x'             => $details->{'start'},
        'y'             => $details->{'h_offset'}-$details->{'padding'},
        'width'         => $details->{'end'}-$details->{'start'},
        'height'        => $details->{'wid'}+$details->{'padding'}*2,
        'bordercolour'  => $details->{'col'},
        'absolutey'     => 1,
        'zmenu'         => $details->{'zmenu'}
    });
}

sub highlight_outbox {
    my $self = shift;
    my $details = shift;
    return new Sanger::Graphics::Glyph::Rect({
        'x'             => $details->{'start'} - $details->{'padding2'} *1.5,
        'y'             => $details->{'h_offset'}-$details->{'padding'} *1.5,
        'width'         => $details->{'end'}-$details->{'start'} + $details->{'padding2'} * 3,
        'height'        => $details->{'wid'}+$details->{'padding'}*3,
        'bordercolour'  => $details->{'col'},
        'absolutey'     => 1,
        'zmenu'         => $details->{'zmenu'}
    });
}

sub highlight_bowtie {
    my $self = shift;
    my $details = shift;
    return new Sanger::Graphics::Glyph::Poly({
        'points'    => [
            $details->{'mid'},                        $details->{'h_offset'},
            $details->{'mid'}-$details->{'padding2'}, $details->{'h_offset'}-$details->{'padding'},
            $details->{'mid'}+$details->{'padding2'}, $details->{'h_offset'}-$details->{'padding'},
            $details->{'mid'},                        $details->{'h_offset'},
            $details->{'mid'},                        $details->{'h_offset'}+$details->{'wid'},
            $details->{'mid'}-$details->{'padding2'}, $details->{'h_offset'}+$details->{'wid'}+$details->{'padding'},
            $details->{'mid'}+$details->{'padding2'}, $details->{'h_offset'}+$details->{'wid'}+$details->{'padding'},
            $details->{'mid'},                        $details->{'h_offset'}+$details->{'wid'}
        ],
        'colour'    => $details->{'col'},
        'absolutey' => 1,
        'zmenu'     => $details->{'zmenu'}
    });
}

sub highlight_labelline {
    my $self = shift;
    my $details = shift;
    my $composite = new Sanger::Graphics::Glyph::Composite();
    $composite->push(
      new Sanger::Graphics::Glyph::Line({
        'x'         => $details->{'mid'},
        'y'         => $details->{'h_offset'}-$details->{'padding'},,
        'width'     => 0,
        'height'    => $details->{'wid'}+$details->{'padding'}*2,
        'colour'    => $details->{'col'},
        'absolutey' => 1,
        'zmenu'     => $details->{'zmenu'}
      })
    );
    return $composite;
} 

sub highlight_wideline {
    my $self = shift;
    my $details = shift;
    return new Sanger::Graphics::Glyph::Line({
        'x'         => $details->{'mid'},
        'y'         => $details->{'h_offset'}-$details->{'padding'},,
        'width'     => 0,
        'height'    => $details->{'wid'}+$details->{'padding'}*2,
        'colour'    => $details->{'col'},
        'absolutey' => 1,
        'zmenu'     => $details->{'zmenu'}
    });
}

sub highlight_text {
    my $self = shift;
    my $details = shift;
    my $composite = new Sanger::Graphics::Glyph::Composite();
  
    $composite->push( 
        new Sanger::Graphics::Glyph::Rect({
        'x'             => $details->{'start'},
        'y'             => $details->{'h_offset'}-$details->{'padding'},
        'width'         => $details->{'end'}-$details->{'start'},
        'height'        => $details->{'wid'}+$details->{'padding'}*2,
        'bordercolour'  => $details->{'col'},
        'absolutey'     => 1,
        })
    );
    # line pointing to feature
    #$composite->push(
    # new Sanger::Graphics::Glyph::Line({
    #   'x'         => $details->{'mid'},
    #   'y'         => $details->{'h_offset'}-$details->{'padding'},,
    #   'width'     => 0,
    #   'height'    => $details->{'wid'}/2,
    #   'colour'    => $details->{'col'},
    #   'absolutey' => 1,
    #  })
    #);
    
    # text label for feature
    $composite->push (new Sanger::Graphics::Glyph::Text({
        'x'         => $details->{'mid'}-$details->{'padding2'},
        'y'         => $details->{'wid'}+$details->{'padding'}*3,
        'width'     => 0,
        'height'    => $details->{'wid'},
        'font'      => 'Tiny',
        'colour'    => $details->{'col'},
        'text'      => $details->{'id'},
        'absolutey' => 1,
        })
    );
    # set up clickable area for complete graphic
    $composite->{'zmenu'}   = $details->{'zmenu'};
    
    return $composite;
}

sub highlight_lharrow {
    my $self = shift;
    my $details = shift;
    return new Sanger::Graphics::Glyph::Poly({
        'points' => [ $details->{'mid'}, $details->{'h_offset'},
            $details->{'mid'}-$details->{'padding2'}, $details->{'h_offset'}-$details->{'padding'},
            $details->{'mid'}+$details->{'padding2'}, $details->{'h_offset'}-$details->{'padding'}
        ],
        'colour' => $details->{'col'},
        'absolutey' => 1,
        'zmenu'  => $details->{'zmenu'}
    });
}

sub highlight_rharrow {
    my $self = shift;
    my $details = shift;
    return new Sanger::Graphics::Glyph::Poly({
        'points' => [ 
            $details->{'mid'}-$details->{'padding2'}, $details->{'h_offset'}+$details->{'wid'}+$details->{'padding'},
            $details->{'mid'}+$details->{'padding2'}, $details->{'h_offset'}+$details->{'wid'}+$details->{'padding'},
            $details->{'mid'}, $details->{'h_offset'}+$details->{'wid'}
        ],
        'colour' => $details->{'col'},
        'absolutey' => 1,
        'zmenu'  => $details->{'zmenu'}
    });
}

sub highlight_rhbox {
  my ($self, $details) = @_;
  $details->{'strand'} = "+";
  return $self->highlight_strandedbox($details);
}

sub highlight_lhbox {
  my ($self, $details) = @_;
  $details->{'strand'} = "-";
  return $self->highlight_strandedbox($details);
}

sub highlight_strandedbox {
  my ($self, $details) = @_;
  my $strand           = $details->{'strand'} || "";
  my $draw_length      = $details->{'end'}-$details->{'start'};
  my $bump_start       = int($details->{'start'} * $self->{'pix_per_bp'});
  $bump_start          = 0 if ($bump_start < 0);
  my $bump_end         = $bump_start + int($draw_length * $self->{'pix_per_bp'}) +1;
  $bump_end            = $self->{'bitmap_length'} if ($bump_end > $self->{'bitmap_length'});
  my $cmap             = $self->{'config'}->colourmap();
  my $ori              = ($strand eq "-")?-1:1;
  my $bitmap           = ($strand eq "-")?"reverse_bitmap":"forward_bitmap";
  my $row              = &Sanger::Graphics::Bump::bump_row(
							   $bump_start,
							   $bump_end,
							   $self->{'bitmap_length'},
							   $self->{$bitmap},
							  );
  my $pos              = 7 + $ori*12 + $ori*$row*($details->{'padding'}+2);
  my $dep              = $self->{'config'}->get('Videogram','dep');

  return if($dep && $row > ($dep-1));
  return Sanger::Graphics::Glyph::Rect->new({
					     #'bordercolour' => "black",
					     'x'            => $details->{'start'},
					     'y'            => $pos,
					     'width'        => $draw_length, #$details->{'end'}-$details->{'start'},
					     'height'       => $details->{'padding'},
					     'colour'       => $details->{'col'},
					     'absolutey'    => 1,
					     'zmenu'        => $details->{'zmenu'}
					    });
}

1;
