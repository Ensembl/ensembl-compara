package Bio::EnsEMBL::GlyphSet::ideogram;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Line;
use SiteDefs;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $chr = $self->{'container'}->chr_name();
    $chr = $chr ? "Chr $chr" : "Chrom. Band";
    $chr .= " " x (12 - length($chr));
	
    my $label = new Sanger::Graphics::Glyph::Text({
    	'text'      => ucfirst($chr),
    	'font'      => 'Small',
    	'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    #########
    # only draw contigs once - on one strand
    #
    return unless ($self->strand() == 1);

    my $Config = $self->{'config'};
    my $col    = undef;
    my $cmap   = $Config->colourmap();
    my $white  = $cmap->id_by_name('white');
    my $black  = $cmap->id_by_name('black');
    my $red    = $cmap->id_by_name('red');
 
    my %COL = ();
    $COL{'gpos100'} = $cmap->id_by_name('black'); #add_rgb([200,200,200]);
    $COL{'gpos75'}  = $cmap->id_by_name('grey75'); #add_rgb([210,210,210]);
    $COL{'gpos50'}  = $cmap->id_by_name('grey50'); #add_rgb([230,230,230]);
    $COL{'gpos25'}  = $cmap->id_by_name('grey25'); #add_rgb([240,240,240]);
    $COL{'gvar'}    = $cmap->id_by_name('grey66');
    $COL{'gneg'}    = $white;
    $COL{'gpos'}    = $black; #add_rgb([240,240,240]);
    $COL{'acen'}    = $cmap->id_by_name('grey33');
    $COL{'tip'}     = $cmap->id_by_name('grey33');
    $COL{'stalk'}   = $cmap->id_by_name('grey33');

    my $im_width = $Config->image_width();
    my ($w,$h)   = $Config->texthelper->px2bp('Tiny');
    my $chr      = $self->{'container'}->chr_name();
    my $len      = $self->{'container'}->length();

    # fetch the chromosome bands that cover this VC.
    my $kba   = $self->{'container'}->adaptor()->db()->get_KaryotypeBandAdaptor();
    my @bands = $kba->fetch_by_chr_name($chr);
    my $chr_length = $self->{'container'}->get_Chromosome()->length();
    
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
		    'points'       => [	$vc_band_start,7, 
					$vc_band_end,2,
					$vc_band_end,12,
				      ],
		    'colour'       => $COL{$stain},
		    'absolutey'    => 1,
		});
	    } else {
		$gband = new Sanger::Graphics::Glyph::Poly({
		    'points'       => [	$vc_band_start,2, 
					$vc_band_end,7,
					$vc_band_start,12,
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
		'points'       => [ $vc_band_start,2, 
				    $vc_band_end,12,
				    $vc_band_end,2,
				    $vc_band_start,12, 
				  ],
		'colour'       => $COL{$stain},
		'absolutey'    => 1,
	    });
	    
	    $self->push($gband);
	    
	    $gband = new Sanger::Graphics::Glyph::Rect({
		'x'      => $vc_band_start,
		'y'      => 5,
		'width'  => $vc_band_end - $vc_band_start,
		'height' => 4,
		'colour' => $COL{$stain},
		'absolutey' => 1,
		});

	    $self->push($gband);

	}
	else {
	    my $gband = new Sanger::Graphics::Glyph::Rect({
		'x'      => $vc_band_start,
		'y'      => 2,
		'width'  => $vc_band_end - $vc_band_start,
		'height' => 10,
		'colour' => $COL{$stain},
		'absolutey' => 1,
		});
	    $self->push($gband);
	    
	   $gband = new Sanger::Graphics::Glyph::Line({
		'x'      => $vc_band_start,
		'y'      => 2,
		'width'  => $vc_band_end - $vc_band_start,
		'height' => 0,
		'colour' => $black,
		'absolutey' => 1,
		});
	    $self->push($gband);
	    
	    $gband = new Sanger::Graphics::Glyph::Line({
		'x'      => $vc_band_start,
		'y'      => 12,
		'width'  => $vc_band_end - $vc_band_start,
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
	my $bp_textwidth = $w * length($bandname);
	unless ($stain eq "acen" || $stain eq "tip" || $stain eq "stalk" ||($bp_textwidth > ($vc_band_end - $vc_band_start))){
		my $tglyph = new Sanger::Graphics::Glyph::Text({
		'x'      => ($vc_band_end + $vc_band_start - $bp_textwidth)/2,
		'y'      => 4,
		'font'   => 'Tiny',
		'colour' => $fontcolour,
		'text'   => $bandname,
		'absolutey'  => 1,
		});
		$self->push($tglyph);
	}
    }

    ##############################################
    # Draw the ends of the ideogram
    ##############################################
    my $gband = new Sanger::Graphics::Glyph::Line({
	'x'      => 0,
	'y'      => 2,
	'width'  => 0,
	'height' => 10,
	'colour' => $black,
	'absolutey' => 1,
	});
    $self->push($gband);
    
    $gband = new Sanger::Graphics::Glyph::Line({
	'x'      => $chr_length,
	'y'      => 2,
	'width'  => 0,
	'height' => 10,
	'colour' => $black,
	'absolutey' => 1,
	});
    $self->push($gband);

    #################################
    # Draw the zoom position red box
    #################################
    $gband = new Sanger::Graphics::Glyph::Rect({
    	'x'      => $self->{'container'}->chr_start(),
    	'y'      => 0,
    	'width'  => $len,
    	'height' => 14,
    	'bordercolour' => $red,
		'absolutey' => 1,
   	});
    $self->push($gband);
}


1;
