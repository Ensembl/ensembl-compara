package Bio::EnsEMBL::GlyphSet::Videogram;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Poly;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Line;
use Bio::EnsEMBL::Glyph::Space;
use SiteDefs;

sub init_label {
    my ($self) = @_;
    return if( $self->{'config'}->{'_label'} eq 'none'  );
    my $chr = $self->{'container'}->{'chr'} || $self->{'extras'}->{'chr'};
    $chr = uc($chr);
    $chr = "Chromosome $chr" if( $self->{'config'}->{'_label'} eq 'above' );
    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => $chr,
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    my $Config = $self->{'config'};
    return unless $Config->container_width()>0; # The container has zero width !!EXIT!!
    
    my $col    = undef;
    my $cmap   = $Config->colourmap();
    my $white  = $cmap->id_by_name('white');
    my $black  = $cmap->id_by_name('black');
    my $bg     = $Config->get('_settings','bgcolor');
    my $red    = $cmap->id_by_name('red');
 
    my %COL = ();
    $COL{'gpos100'} = $cmap->id_by_name('black'); #add_rgb([200,200,200]);
    $COL{'tip'}     = $cmap->id_by_name('slategrey');
    $COL{'gpos75'}  = $cmap->id_by_name('grey3'); #add_rgb([210,210,210]);
    $COL{'gpos50'}  = $cmap->id_by_name('grey2'); #add_rgb([230,230,230]);
    $COL{'gpos25'}  = $cmap->id_by_name('grey1'); #add_rgb([240,240,240]);
    $COL{'gpos'}    = $black; #add_rgb([240,240,240]);
    $COL{'gvar'}    = $cmap->add_rgb([222,220,220]);
    $COL{'gneg'}    = $white;
    $COL{'acen'}    = $cmap->id_by_name('slategrey');
    $COL{'stalk'}   = $cmap->id_by_name('slategrey');

    my $im_width    = $Config->image_width();
    my $top_margin  = $Config->{'_top_margin'};
    my ($w,$h)      = $Config->texthelper->Vpx2bp('Tiny');
    my $chr         = $self->{'container'}->{'chr'} || $self->{'extras'}->{'chr'};

    # fetch the chromosome bands that cover this VC.
    my $kba         = $self->{'container'}->{'ka'};
    my @bands       = $kba->fetch_all_by_chromosome($chr);
    my $chr_length  = $kba->fetch_chromosome_length($chr) || 1;
    my $v_offset    = $Config->container_width() - $chr_length; # bottom align each chromosome!
    my $bpperpx     = $Config->container_width()/$Config->{'_image_height'};
    # over come a bottom border/margin problem....

    my $done_1_acen = 0;        # flag for tracking place in chromsome
    my $wid         = $Config->get('Videogram','width');
    my $h_wid       = int($wid/2);
    my $padding     = $Config->get('Videogram','padding');
        
    # max width of band label is 6 characters
    my $h_offset    = int(
        $self->{'config'}->get('Videogram','totalwidth')
            - $wid
            - ($self->{'config'}->{'_band_labels'} eq 'on' ? ($w * 6 + 4) : 0 )
    )/2;

    my @decorations;
    if($padding) {
    # make sure that there is a blank image behind the chromosome so that the
    # glyhset doesn't get "horizontally" squashed.
        my $gpadding = new Bio::EnsEMBL::Glyph::Space({
            'x'         => 0,
            'y'         => $h_offset - $padding,
            'width'     => 10000,
            'height'    => $padding * 2 + $wid,
            'absolutey' => 1,
        });
        $self->push($gpadding);        
    }
    foreach my $band (@bands){
        my $bandname       = $band->name();
        my $vc_band_start  = $band->start() + $v_offset;
        my $vc_band_end    = $band->end() + $v_offset;
        my $stain          = $band->stain();

        my $HREF;
        if($self->{'config'}->{'_band_links'}) {
            $HREF = "/$ENV{'ENSEMBL_SPECIES'}/contigview?chr=$chr&vc_start=$vc_band_start&vc_end=$vc_band_end";
        }
        if ($stain eq "acen"){
            my $gband;
            if ($done_1_acen){
                $gband = new Bio::EnsEMBL::Glyph::Poly({
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
                $gband = new Bio::EnsEMBL::Glyph::Poly({
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
            my $gband = new Bio::EnsEMBL::Glyph::Poly({
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
            $gband = new Bio::EnsEMBL::Glyph::Rect({
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
            $stain = 'gneg' if($self->{'config'}->{'_hide_bands'} eq 'yes' );
            my $gband = new Bio::EnsEMBL::Glyph::Rect({
                'x'                => $vc_band_start,
                'y'                => $h_offset,
                'width'            => $vc_band_end - $vc_band_start,
                'height'           => $wid,
                'colour'           => $COL{$stain},
                'absolutey'        => 1,
                'href'             => $HREF
            });
            $self->push($gband);
            $gband = new Bio::EnsEMBL::Glyph::Line({
                'x'                => $vc_band_start,
                'y'                => $h_offset,
                'width'            => $vc_band_end - $vc_band_start,
                'height'           => 0,
                'colour'           => $black,
                'absolutey'        => 1,
            });
            $self->push($gband);
            $gband = new Bio::EnsEMBL::Glyph::Line({
                'x'                => $vc_band_start,
                'y'                => $h_offset+$wid,
                'width'            => $vc_band_end - $vc_band_start,
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
            my $tglyph = new Bio::EnsEMBL::Glyph::Text({
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

	foreach( @decorations ) {
		$self->push($_);
	}
    ##############################################
    # Draw the ends of the ideogram
    ##############################################
# Top of chromosome
    my @lines = $wid < 16 ?
        ( [8,6],[4,4],[2,2] ) :
        ( [8,5],[5,3],[4,1],[3,1],[2,1],[1,1],[1,1],[1,1] ) ;
    
    foreach my $end ( 
        ( $bands[ 0]->stain() eq 'tip' ? () : 0 ),
        ( $bands[-1]->stain() eq 'tip' ? () : 1 )
     ) {
        my $direction = $end ? -1 : 1;
        foreach my $I ( 0..$#lines ) {
            my ( $bg_x, $black_x ) = @{$lines[$I]};
            my $xx = $v_offset + $chr_length * $end + ($I+.5 * $end) * $direction * $bpperpx +(1-$end)*10;
            my $glyph = new Bio::EnsEMBL::Glyph::Line({
                'x'         => $xx,
                'y'         => $h_offset,
                'width'     => 0,
                'height'    => $wid * $bg_x/24 -1,
                'colour'    => $bg,
                'absolutey' => 1,
            });
            $self->push($glyph);
            $glyph = new Bio::EnsEMBL::Glyph::Line({
                'x'         => $xx,
                'y'         => $h_offset + 1 + $wid * (1-$bg_x/24),
                'width'     => 0,
                'height'    => $wid * $bg_x/24 -1 ,
                'colour'    => $bg,
                'absolutey' => 1,
            }) ;
            $self->push($glyph);
            $glyph = new Bio::EnsEMBL::Glyph::Line({
                'x'         => $xx,
                'y'         => $h_offset + $wid * $bg_x/24,
                'width'     => 0,
                'height'    => $wid * $black_x/24 -1 ,
                'colour'    => $black,
                'absolutey' => 1,
            });
            $self->push($glyph);
            $glyph = new Bio::EnsEMBL::Glyph::Line({
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
    		if($highlight_set->{'merge'} eq 'no') {
				@highlights = @temp_highlights;
			} else {
				my @bin_flag;
				my $bin_length = $padding * ( $highlight_style eq 'arrow' ? 1.5 : 1 ) * $bpperpx;
				foreach(@temp_highlights) {
					my $bin_id = int( (2 * $v_offset+ $_->{'start'}+$_->{'end'}) / 2 / $bin_length );
                    $bin_id = 0 if $bin_id<0;
					if(my $offset = $bin_flag[$bin_id]) { # We already have a highlight in this bin - so add this one to it!
						my $zmenu_length = keys %{$highlights[$offset]->{'zmenu'}};
						foreach my $entry (sort keys %{$_->{'zmenu'}}) { 
							next if $entry eq 'caption';
							my $value = $_->{'zmenu'}->{$entry};
							$entry=~s/\d\d+://;
							$highlights[$offset]->{'zmenu'}->{ sprintf("%02d:%s",$zmenu_length++,$entry) }
								= $value;
							$highlights[$offset]->{'start'} = $_->{'start'} if
								($highlights[$offset]->{'start'} > $_->{'start'});
							$highlights[$offset]->{'end'} = $_->{'end'} if
								($highlights[$offset]->{'end'} < $_->{'end'});
						}
					} else { # We don't
						push @highlights, $_;
						$bin_flag[$bin_id] = $#highlights;
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
                my $col          = $_->{'col'};
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
                    } );
					$self->push($g);
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
    return new Bio::EnsEMBL::Glyph::Rect({
        'x'         => $details->{'start'},
        'y'         => $details->{'h_offset'},
        'width'     => $details->{'end'}-$details->{'start'},
        'height'    => $details->{'wid'},
        'colour'    => $details->{'col'},
        'absolutey' => 1,
        'zmenu'     => $details->{'zmenu'}
    });
}

sub highlight_widebox {
    my $self = shift;
    my $details = shift;
    return new Bio::EnsEMBL::Glyph::Rect({
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
    return new Bio::EnsEMBL::Glyph::Rect({
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
    return new Bio::EnsEMBL::Glyph::Poly({
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

sub highlight_wideline {
    my $self = shift;
    my $details = shift;
	return new Bio::EnsEMBL::Glyph::Line({
        'x'         => $details->{'mid'},
        'y'         => $details->{'h_offset'}-$details->{'padding'},,
        'width'     => 0,
        'height'    => $details->{'wid'}+$details->{'padding'}*2,
        'colour'    => $details->{'col'},
        'absolutey' => 1,
        'zmenu'     => $details->{'zmenu'}
    });
}

sub highlight_lharrow {
    my $self = shift;
    my $details = shift;
    return new Bio::EnsEMBL::Glyph::Poly({
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
    return new Bio::EnsEMBL::Glyph::Poly({
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
1;
