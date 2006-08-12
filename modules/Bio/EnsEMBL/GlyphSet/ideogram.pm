package Bio::EnsEMBL::GlyphSet::ideogram;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Line;

my %SHORT = qw(
  chromosome Chr.
  supercontig S'ctg
);

sub init_label {
  my ($self) = @_;
  return if( defined $self->{'config'}->{'_no_label'} );
  my $type = $self->{'container'}->coord_system->name();

  $type = $SHORT{lc($type)} || ucfirst( $type );
  my $chr = $self->{'container'}->seq_region_name();
  my $chr_raw = $chr;
  $chr = "$type $chr" unless $chr =~ /^$type/i;
  if( $self->{'config'}->{'multi'} ) {
	if( length($chr) > 9 ) {
  	  $chr = $chr_raw;
    }
    $chr = join( '', map { substr($_,0,1) } split( /_/, $self->{'config'}->{'species'}),'.')." $chr";
  }
  $self->init_label_text(ucfirst($chr));
}

sub _init {
    my ($self) = @_;

    #########
    # only draw contigs once - on one strand
    #
    return unless ($self->strand() == 1);

    my $Config = $self->{'config'};
    my $col    = undef;
    my $white  = 'white';
    my $black  = 'black';
    my $red    = 'red';
 
    my %COL = ();
    $COL{'gpos100'} = 'black'; #add_rgb([200,200,200]);
    $COL{'tip'}     = 'slategrey';
    $COL{'gpos75'}  = 'grey40'; #add_rgb([210,210,210]);
    $COL{'gpos50'}  = 'grey60'; #add_rgb([230,230,230]);
    $COL{'gpos25'}  = 'grey85'; #add_rgb([240,240,240]);
    $COL{'gpos'}    = 'black'; #add_rgb([240,240,240]);
    $COL{'gvar'}    = 'grey88';  #add_rgb([222,220,220]);
    $COL{'gneg'}    = 'white';
    $COL{'acen'}    = 'slategrey';
    $COL{'stalk'}   = 'slategrey';
    $COL{'mark'}    = 'blue'; # marks start/end of annotated sequence

    my $im_width = $Config->image_width();
    my ($w,$h)   = $Config->texthelper->px2bp($self->{'config'}->species_defs->ENSEMBL_STYLE->{'GRAPHIC_FONT'});
    my $chr      = $self->{'container'}->seq_region_name();
    my $len      = $self->{'container'}->length();

    # fetch the chromosome bands that cover this VC.
    my $kba   = $self->{'container'}->adaptor()->db()->get_KaryotypeBandAdaptor();
    my $bands = $kba->fetch_all_by_chr_name($chr);
    my $chr_length = $self->{'container'}->length();
    
    # get rid of div by zero...
    $chr_length |= 1;
	
    # over come a bottom border/margin problem....
    my $hack = new Sanger::Graphics::Glyph::Rect({
		'x'      => 1,
		'y'      => 0,
		'width'  => 1,
		'height' => 20,
		'bordercolour' => $white,
		'absolutey' => 1,
    });
    $self->push($hack);
    
    my $done_one_acen = 0;	    # flag for tracking place in chromsome

    my( $fontname, $fontsize ) = $self->get_font_details( 'innertext' );
    my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
    my $h = $res[3];
    my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};

    my @bands =  sort{$a->start <=> $b->start } @$bands;
    if(@bands) {
      foreach my $band (@bands){
	my $bandname       = $band->name();
# 	my $band2          = $self->{'container'}->fetch_karyotype_band_by_name($chr,$bandname);
# 	my $vc_band_start  = $band2->start();
# 	my $vc_band_end    = $band2->end();
# 	my $stain          = $band2->stain();

	my $vc_band_start  = $band->start();
	my $vc_band_end    = $band->end();
	my $stain          = $band->stain();

#	print STDERR "$chr band:$bandname stain:$stain start:$vc_band_start end:$vc_band_end\n";		

	if ($stain eq "acen"){
	    my $gband;
	    if ($done_one_acen){
		$gband = new Sanger::Graphics::Glyph::Poly({
		    'points'       => [	$vc_band_start-1,2+($h+2)/2, 
					$vc_band_end,2,
					$vc_band_end,2+($h+2),
				      ],
		    'colour'       => $COL{$stain},
		    'absolutey'    => 1,
		});
	    } else {
		$gband = new Sanger::Graphics::Glyph::Poly({
		    'points'       => [	$vc_band_start-1,2, 
					$vc_band_end, 2+($h+2)/2,
					$vc_band_start,2+$h+2,
					],
		    'colour'       => $COL{$stain},
		    'absolutey'    => 1,
		});
		
		$done_one_acen = 1;
	    }
	    
	    $self->push($gband);
	} 
	elsif ($stain eq "stalk"){
	    my $gband = new Sanger::Graphics::Glyph::Poly({
		'points'       => [ $vc_band_start-1,2, 
				    $vc_band_end,4+$h,
				    $vc_band_end,2,
				    $vc_band_start-1,4+$h, 
				  ],
		'colour'       => $COL{$stain},
		'absolutey'    => 1,
	    });
	    
	    $self->push($gband);
	    
	    $gband = new Sanger::Graphics::Glyph::Rect({
		'x'      => $vc_band_start-1,
		'y'      => ($h+2)/4 + 2,
		'width'  => $vc_band_end - $vc_band_start + 1,
		'height' => ($h+2)/2 - 1,
		'colour' => $COL{$stain},
		'absolutey' => 1,
		});

	    $self->push($gband);

	}
	else {
	    my $gband = new Sanger::Graphics::Glyph::Rect({
		'x'      => $vc_band_start -1,
		'y'      => 2,
		'width'  => $vc_band_end - $vc_band_start + 1,
		'height' => $h+2,
		'colour' => $COL{$stain},
		'absolutey' => 1,
		});
	    $self->push($gband);
	    
	   $gband = new Sanger::Graphics::Glyph::Line({
		'x'      => $vc_band_start,
		'y'      => 2,
		'width'  => $vc_band_end - $vc_band_start + 1,
		'height' => 0,
		'colour' => $black,
		'absolutey' => 1,
		});
	    $self->push($gband);
	    
	    $gband = new Sanger::Graphics::Glyph::Line({
		'x'      => $vc_band_start,
		'y'      => $h+4,
		'width'  => $vc_band_end - $vc_band_start + 1,
		'height' => 0,
		'colour' => $black,
		'absolutey' => 1,
		});
	    $self->push($gband);
	}
	my $fontcolour;

	##########################################################
	# change label colour to white if the chr band is dark...
	##########################################################
	if ($stain eq "gpos100" || $stain eq "gpos75"){
		$fontcolour = $white;
	} else {
		$fontcolour = $black;
	}
	
	#################################################################
	# only add the band label if the box is big enough to hold it...
	#################################################################
   my @res = $self->get_text_width( ($vc_band_end-$vc_band_start)*$pix_per_bp, $bandname, '', 'font'=>$fontname, 'ptsize' => $fontsize );
   if( $res[0] && $stain ne "tip" && $stain ne "acen" && $stain ne 'stalk' ){
      my $tglyph = new Sanger::Graphics::Glyph::Text({
        'x'      => int(($vc_band_end + $vc_band_start-$res[2]/$pix_per_bp)/2),
        'y'      => ($h-$res[3])/2+1,
        'width'  => $res[2]/$pix_per_bp,
        'textwidth' => $res[2],
        'font'   => $fontname,
        'height' => $res[3],
        'ptsize' => $fontsize,
        'colour' => $fontcolour,
        'text'   => $res[0],
        'absolutey'  => 1,
      });
      $self->push($tglyph);
    }

      }
    } else {
      my $gband = new Sanger::Graphics::Glyph::Line({
                'x'      => 0,
                'y'      => 2,
                'width'  => $chr_length,
                'height' => 0,
                'colour' => $black,
                'absolutey' => 1,
                });
            $self->push($gband);

            $gband = new Sanger::Graphics::Glyph::Line({
                'x'      => 0,
                'y'      => $h + 6,
                'width'  => $chr_length,
                'height' => 0,
                'colour' => $black,
                'absolutey' => 1,
                });
            $self->push($gband);
    }

    ##############################################
    # Draw the ends of the ideogram
    ##############################################
    foreach my $end (qw(0 1)) {
        my $direction = $end ? 1 : -1;
        my %partials = map { uc($_) => 1 }
                @{ $self->species_defs->PARTIAL_CHROMOSOMES || [] };
        if ($partials{uc($chr)}) {
        # draw jagged ends for partial chromosomes
            my $bpperpx = $chr_length/$im_width;
            foreach my $i (1..4) {
                my $x = $chr_length * $end + 4 * (($i % 2) - 1) * $direction * $bpperpx;
                my $y = 2 + ($h+2)/4 * ($i - 1);
                my $width = 4 * (1 - 2 * ($i % 2)) * $direction * $bpperpx;
                my $height = ($h+2)/4;
                # overwrite karyotype bands with appropriate triangles to
                # produce jags
                my $triangle = new Sanger::Graphics::Glyph::Poly({
                    'points'    => [
                        $x, $y,
                        $x + $width * (1 - ($i % 2)),$y + $height * ($i % 2),
                        $x + $width, $y + $height,
                    ],
                    'colour'    => $white,
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
            foreach (0, 10) {
                $self->push(new Sanger::Graphics::Glyph::Line({
                    'x'                => 0,
                    'y'                => 2 + $_,
                    'width'            => 4,
                    'height'           => 0,
                    'colour'           => $black,
                    'absolutey'        => 1,
                    'absolutewidth'    => 1,
                }));
            }
        } else {
        # draw blunt ends for full chromosomes
            my $gband = new Sanger::Graphics::Glyph::Line({
                'x'      => $chr_length * $end,
                'y'      => 2,
                'width'  => 0,
                'height' => $h+2,
                'colour' => $black,
                'absolutey' => 1,
                });
            $self->push($gband);
        }
    }

    #################################
    # Draw the zoom position red box
    #################################
  my $rbs = $Config->get('_settings','red_box_start');
  my $rbe = $Config->get('_settings','red_box_end');
  if ($Config->get('_settings','draw_red_box') eq 'yes') {
    # only draw focus box on the correct display...
    $self->push( new Sanger::Graphics::Glyph::Rect({
      'x'            => $rbs,
      'y'            => 0,
      'width'        => $rbe-$rbs+1,
      'height'       => $h+8,
      'bordercolour' => $red,
      'absolutey'    => 1,
    }) );
    $self->push( new Sanger::Graphics::Glyph::Rect({
      'x'            => $rbs,
      'y'            => 1,
      'width'        => $rbe-$rbs+1,
      'height'       => $h+6,
      'bordercolour' => $red,
      'absolutey'    => 1,
    }) );
  }
}


1;
