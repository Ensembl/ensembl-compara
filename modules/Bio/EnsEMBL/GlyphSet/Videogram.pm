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
    $chr =~s/^chr//;
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
    my $col    = undef;
    my $cmap   = $Config->colourmap();
    my $white  = $cmap->id_by_name('white');
    my $black  = $cmap->id_by_name('black');
    my $red    = $cmap->id_by_name('red');
 
    my %COL = ();
    $COL{'gpos100'} = $cmap->id_by_name('black'); #add_rgb([200,200,200]);
    $COL{'gpos75'}  = $cmap->id_by_name('grey3'); #add_rgb([210,210,210]);
    $COL{'gpos50'}  = $cmap->id_by_name('grey2'); #add_rgb([230,230,230]);
    $COL{'gpos25'}  = $cmap->id_by_name('grey1'); #add_rgb([240,240,240]);
    $COL{'gvar'}    = $cmap->id_by_name('offwhite'); #add_rgb([222,220,220]);
    $COL{'gneg'}    = $white;
    $COL{'acen'}    = $cmap->id_by_name('slategrey');
    $COL{'stalk'}   = $cmap->id_by_name('slategrey');

    my $im_width    = $Config->image_width();

    my ($w,$h)      = $Config->texthelper->Vpx2bp('Tiny');
    my $chr         = $self->{'container'}->{'chr'} || $self->{'extras'}->{'chr'};
    print STDERR "Videogram: $chr\n";

    # fetch the chromosome bands that cover this VC.
    my $kba         = $self->{'container'}->{'ka'};
    my @bands       = $kba->fetch_all_by_chromosome("chr$chr");
    my $chr_length  = $kba->fetch_chromosome_length("chr$chr") || 1;
    my $v_offset    = $Config->container_width() - $chr_length; # bottom align each chromosome!
	my $bpperpx     = $Config->container_width()/$Config->{'_image_height'};
	
    # over come a bottom border/margin problem....

    my $done_1_acen = 0;	    # flag for tracking place in chromsome
	my $wid   		= $self->{'config'}->get('Videogram','width');
	my $h_wid 		= int($wid/2);
	my $padding     = $self->{'config'}->get('Videogram','padding');
		
	# max width of band label is 6 characters
	my $h_offset    = int(
		$self->{'config'}->get('Videogram','totalwidth')
			- $wid
			- ($self->{'config'}->{'_band_labels'} eq 'on' ? ($w * 6 + 4) : 0 )
	)/2;


	if($padding) {
	# make sure that there is a blank image behind the chromosome so that the
	# glyhset doesn't get "horizontally" squashed.
		my $gpadding = new Bio::EnsEMBL::Glyph::Space({
			'x'      => 0,
			'y'      => $h_offset - $padding,
			'width'  => 10000,
			'height' => $padding * 2 + $wid,
			'absolutey'    => 1,
		});
	    $self->push($gpadding);		
	}
    foreach my $band (@bands){
		my $bandname       = $band->name();
		my $vc_band_start  = $band->start() + $v_offset;
		my $vc_band_end    = $band->end() + $v_offset;
		my $stain          = $band->stain();

#	print STDERR "$chr band:$bandname stain:$stain start:$vc_band_start end:$vc_band_end\n";		
		my $HREF;
		if($self->{'config'}->{'_band_links'}) {
			$HREF = "/$ENV{'ENSEMBL_SPECIES'}/contigview?chr=$chr&vc_start=$vc_band_start&vc_end=$vc_band_end";
		}
		if ($stain eq "acen"){
		    my $gband;
		    if ($done_1_acen){
				$gband = new Bio::EnsEMBL::Glyph::Poly({
				    'points'       => [	$vc_band_start,$h_offset + $h_wid, 
										$vc_band_end,$h_offset,
										$vc_band_end,$h_offset + $wid,
								      ],
				    'colour'       => $COL{$stain},
				    'absolutey'    => 1,
					'href'         => $HREF
				});
		    } else {
				$gband = new Bio::EnsEMBL::Glyph::Poly({
				    'points'       => [	$vc_band_start,$h_offset, 
							$vc_band_end,$h_offset + $h_wid,
							$vc_band_start,$h_offset + $wid,
							],
				    'colour'       => $COL{$stain},
				    'absolutey'    => 1,
					'href'         => $HREF
				});
				$done_1_acen = 1;
		    }
			$self->push($gband);
		} elsif ($stain eq "stalk"){
		    my $gband = new Bio::EnsEMBL::Glyph::Poly({
				'points'       => [ $vc_band_start,$h_offset, 
							    $vc_band_end,$h_offset + $wid,
							   $vc_band_end,$h_offset,
								$vc_band_start,$h_offset + $wid, 
				],
				'colour'       => $COL{$stain},
				'absolutey'    => 1,
					'href'			=> $HREF
	    	});
	    
	    $self->push($gband);
	    $gband = new Bio::EnsEMBL::Glyph::Rect({
		'x'      => $vc_band_start,
		'y'      => $h_offset+ int($wid/4),
		'width'  => $vc_band_end - $vc_band_start,
		'height' => $h_wid,
		'colour' => $COL{$stain},
		'absolutey' => 1,
		'href'         => $HREF
		});

	    $self->push($gband);

	}
	else {
	    my $gband = new Bio::EnsEMBL::Glyph::Rect({
		'x'      => $vc_band_start,
		'y'      => $h_offset,
		'width'  => $vc_band_end - $vc_band_start,
		'height' => $wid,
		'colour' => $COL{$stain},
		'absolutey' => 1,
			'href'         => $HREF
		});
	    $self->push($gband);
	   $gband = new Bio::EnsEMBL::Glyph::Line({
		'x'      => $vc_band_start,
		'y'      => $h_offset,
		'width'  => $vc_band_end - $vc_band_start,
		'height' => 0,
		'colour' => $black,
		'absolutey' => 1,
		});
	    $self->push($gband);
	    $gband = new Bio::EnsEMBL::Glyph::Line({
		'x'      => $vc_band_start,
		'y'      => $h_offset+$wid,
		'width'  => $vc_band_end - $vc_band_start,
		'height' => 0,
		'colour' => $black,
		'absolutey' => 1,
		});
	    $self->push($gband);
	}
	my $fontcolour;

	#################################################################
	# only add the band label if the box is big enough to hold it...
	#################################################################

	unless ($stain eq "acen" || $stain eq "stalk" || ($self->{'config'}->{'_band_labels'} ne 'on') ||
			($h > ($vc_band_end - $vc_band_start)) ){
		my $tglyph = new Bio::EnsEMBL::Glyph::Text({
		'x'      => ($vc_band_end + $vc_band_start - $h)/2,
		'y'      => $h_offset+$wid+4,
		'width'  => $h,
		'height' => $w * length($bandname),
		'font'   => 'Tiny',
		'colour' => $black,
		'text'   => $bandname,
		'absolutey'  => 1,
		'href'         => $HREF		
		});
		$self->push($tglyph);
	}
    }

    ##############################################
    # Draw the ends of the ideogram
    ##############################################
    my $gband = new Bio::EnsEMBL::Glyph::Line({
	'x'      => $v_offset,
	'y'      => $h_offset,
	'width'  => 0,
	'height' => $wid,
	'colour' => $black,
	'absolutey' => 1,
	});
    $self->push($gband);
    
    $gband = new Bio::EnsEMBL::Glyph::Line({
	'x'      => $chr_length + $v_offset,
	'y'      => $h_offset,
	'width'  => 0,
	'height' => $wid,
	'colour' => $black,
	'absolutey' => 1,
	});
    $self->push($gband);

    #######################################
    # Do the highlighting bit at the end!!!
    #######################################
  if($self->{'highlights'}->{"chr$chr"}) {
	my $high_flag = 'l';
	
	foreach( sort { $a->{'start'} <=> $b->{'start'} } @{$self->{'highlights'}->{"chr$chr"}} ) {
		my $start     = $v_offset + $_->{'start'};
		my $end       = $v_offset + $_->{'end'};
		my $type;
		if( $_->{'type'} eq 'arrow' ) {
			$type      = "highlight_$high_flag".'harrow';
			$high_flag = $high_flag eq 'r' ? 'l' : 'r';
		} else {
			$type      = "highlight_$_->{'type'}";
		}
		my $zmenu     = $_->{'zmenu'};
		my $col		  = $_->{'col'};
		print STDERR "$type: $start: $end: $zmenu: $col\n";
    	########## dynamic require of the right type of renderer
		if($self->can($type)) {
			$self->$type( {
				'chr'      => $chr,
				'start'    => $start,
				'end'      => $end,
				'mid'      => ($start+$end)/2,
				'h_offset' => $h_offset,
				'wid'    => $wid,
				'padding'  => $padding,
				'padding2'  => $padding * $bpperpx * sqrt(3)/2,
				'zmenu'    => $zmenu,
				'col'	   => $col,
			} );
		}
	}
  }
}

sub highlight_box {
	my $self = shift;
	my $details = shift;
    my $g = new Bio::EnsEMBL::Glyph::Rect({
	'x'      => $details->{'start'},
	'y'      => $details->{'h_offset'},
	'width'  => $details->{'end'}-$details->{'start'},
	'height' => $details->{'wid'},
	'colour' => $details->{'col'},
	'absolutey' => 1,
	'zmenu'  => $details->{'zmenu'}
	});
    $self->push($g);
}

sub highlight_widebox {
	my $self = shift;
	my $details = shift;
    my $g = new Bio::EnsEMBL::Glyph::Rect({
	'x'      => $details->{'start'},
	'y'      => $details->{'h_offset'}-$details->{'padding'},
	'width'  => $details->{'end'}-$details->{'start'},
	'height' => $details->{'wid'}+$details->{'padding'}*2,
	'bordercolour' => $details->{'col'},
	'absolutey' => 1,
	'zmenu'  => $details->{'zmenu'}
	});
    $self->push($g);
}

sub highlight_bowtie {
	my $self = shift;
	my $details = shift;
	foreach(keys %$details) { print STDERR "BOWTIE: $_ : $details->{$_}\n"; } print STDERR "\n";
    my $g = new Bio::EnsEMBL::Glyph::Poly({
		'points' => [
			$details->{'mid'}, 							$details->{'h_offset'},
			$details->{'mid'}-$details->{'padding2'}, 	$details->{'h_offset'}-$details->{'padding'},
			$details->{'mid'}+$details->{'padding2'}, 	$details->{'h_offset'}-$details->{'padding'},
			$details->{'mid'}, 							$details->{'h_offset'},
			$details->{'mid'}, 							$details->{'h_offset'}+$details->{'wid'},
			$details->{'mid'}-$details->{'padding2'}, 	$details->{'h_offset'}+$details->{'wid'}+$details->{'padding'},
			$details->{'mid'}+$details->{'padding2'}, 	$details->{'h_offset'}+$details->{'wid'}+$details->{'padding'},
			$details->{'mid'}, 							$details->{'h_offset'}+$details->{'wid'}
		],
	'colour' => $details->{'col'},
	'absolutey' => 1,
	'zmenu'  => $details->{'zmenu'}
	});
    $self->push($g);
}

sub highlight_wideline {
	my $self = shift;
	my $details = shift;
    my $g = new Bio::EnsEMBL::Glyph::Line({
	'x'      => $details->{'mid'},
	'y'      => $details->{'h_offset'}-$details->{'padding'},,
	'width'  => 0,
	'height' => $details->{'wid'}+$details->{'padding'}*2,
	'colour' => $details->{'col'},
	'absolutey' => 1,
	'zmenu'  => $details->{'zmenu'}
	});
    $self->push($g);
}

sub highlight_lharrow {
	my $self = shift;
	my $details = shift;
    my $g = new Bio::EnsEMBL::Glyph::Poly({
		'points' => [ $details->{'mid'}, $details->{'h_offset'},
			$details->{'mid'}-$details->{'padding2'}, $details->{'h_offset'}-$details->{'padding'},
			$details->{'mid'}+$details->{'padding2'}, $details->{'h_offset'}-$details->{'padding'}
		],
	'colour' => $details->{'col'},
	'absolutey' => 1,
	'zmenu'  => $details->{'zmenu'}
	});
    $self->push($g);
}

sub highlight_rharrow {
	my $self = shift;
	my $details = shift;
    my $g = new Bio::EnsEMBL::Glyph::Poly({
		'points' => [ 
			$details->{'mid'}-$details->{'padding2'}, $details->{'h_offset'}+$details->{'wid'}+$details->{'padding'},
			$details->{'mid'}+$details->{'padding2'}, $details->{'h_offset'}+$details->{'wid'}+$details->{'padding'},
			$details->{'mid'}, $details->{'h_offset'}+$details->{'wid'}
		],
	'colour' => $details->{'col'},
	'absolutey' => 1,
	'zmenu'  => $details->{'zmenu'}
	});
    $self->push($g);
}
1;
