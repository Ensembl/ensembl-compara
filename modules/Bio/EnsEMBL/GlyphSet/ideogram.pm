package Bio::EnsEMBL::GlyphSet::ideogram;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Poly;
use Bio::EnsEMBL::Glyph::Text;
use SiteDefs;
use ColourMap;

sub init_label {
    my ($self) = @_;

	my $chr = $self->{'container'}->_chr_name();
	$chr ||= "Chrom. Band";
	$chr .= " " x (12 - length($chr));
	
    my $label = new Bio::EnsEMBL::Glyph::Text({
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

    my $col   = undef;
    my $cmap  = new ColourMap;
    my $white = $cmap->id_by_name('white');
    my $black = $cmap->id_by_name('black');
    my $red   = $cmap->id_by_name('red');
 
	my %COL = ();
	$COL{'gpos100'} = $cmap->id_by_name('black'); #add_rgb([200,200,200]);
	$COL{'gpos75'}  = $cmap->id_by_name('grey3'); #add_rgb([210,210,210]);
	$COL{'gpos50'}  = $cmap->id_by_name('grey2'); #add_rgb([230,230,230]);
	$COL{'gpos25'}  = $cmap->id_by_name('grey1'); #add_rgb([240,240,240]);
	$COL{'gvar'}    = $cmap->id_by_name('offwhite'); #add_rgb([222,220,220]);
	$COL{'gneg'}    = $white;
	$COL{'acen'}    = $cmap->id_by_name('slategrey');
	$COL{'stalk'}   = $cmap->id_by_name('slategrey');

    my $im_width = $self->{'config'}->image_width();
	my ($w,$h) = $self->{'config'}->texthelper->px2bp('Tiny');
	my $chr = $self->{'container'}->_chr_name();
	my $len = $self->{'container'}->length();

	# fetch the chromosome bands that cover this VC.
	my $kba = $self->{'container'}->fetch_karyotype_adaptor();
	my @bands = $kba->fetch_all_by_chromosome($chr);
	my $chr_length = $self->{'container'}->fetch_chromosome_length();
	
	# get rid of div by zero...
	my $chr_length |= 1;
	print STDERR "Chr length: $chr_length\n";
	my $vc2chr = $len/$chr_length;
	
	# over come a bottom border/margin problem....
    my $hack = new Bio::EnsEMBL::Glyph::Rect({
    	'x'      => 1,
    	'y'      => 0,
    	'width'  => 1,
    	'height' => 20,
    	'bordercolour' => $white,
		'absolutey' => 1,
   	});
    $self->push($hack);

	foreach my $band (@bands){

		my $bandname = $band->name();
		my $band2  = $self->{'container'}->fetch_karyotype_band_by_name($chr,$bandname);
		my $start  = $band2->start();
		my $end    = $band2->end();
		my $stain  = $band2->stain();
		my ($vc_band_start,$vc_band_end) = ();
		
		$vc_band_start	= $start * $vc2chr; 
		$vc_band_end	= $end * $vc2chr;
		#print STDERR "$chr band:$bandname stain:$stain start:$vc_band_start end:$vc_band_end\n";		

		if ($stain eq "acen"){
			# need to draw centromeres and 2nd contricts differently....dunno how yet though.
    		my $gband = new Bio::EnsEMBL::Glyph::Rect({
    			'x'      => $vc_band_start,
    			'y'      => 2,
    			'width'  => $vc_band_end - $vc_band_start,
    			'height' => 10,
    			'colour' => $COL{$stain},
				'absolutey' => 1,
   			});
    		$self->push($gband);
		} else {
    		my $gband = new Bio::EnsEMBL::Glyph::Rect({
    			'x'      => $vc_band_start,
    			'y'      => 2,
    			'width'  => $vc_band_end - $vc_band_start,
    			'height' => 10,
    			'colour' => $COL{$stain},
				'absolutey' => 1,
   			});
    		$self->push($gband);
		}
		my $fontcolour;
		# change label colour to white if the chr band is dark...
		if ($stain eq "gpos100" || $stain eq "acen" || $stain eq "stalk" || $stain eq "gpos75"){
			$fontcolour = $white;
		} else {
			$fontcolour = $black;
		}
		my $bp_textwidth = $w * length($bandname);
		# only add the lable if the box is big enough to hold it...
		unless ($bp_textwidth > ($vc_band_end - $vc_band_start)){
			my $tglyph = new Bio::EnsEMBL::Glyph::Text({
			'x'      => $vc_band_start + ($vc_band_end - $vc_band_start)/2 - ($bp_textwidth)/2,
			'y'      => 4,
			'font'   => 'Tiny',
			'colour' => $fontcolour,
			'text'   => $bandname,
			'absolutey'  => 1,
			});
			$self->push($tglyph);
		}
		#print STDERR "VCSTART: $vc_band_start, VCEND: $vc_band_end, WIDTH: ",$vc_band_end - $vc_band_start, "\n";
		#print STDERR "VC length: ", $self->{'container'}->length(), "\n";
		#print STDERR "Stain: $stain = ", $COL{$stain}, "\n";
	}

    my $gband = new Bio::EnsEMBL::Glyph::Rect({
    	'x'      => 0,
    	'y'      => 2,
    	'width'  => $len,
    	'height' => 10,
    	'bordercolour' => $black,
		'absolutey' => 1,
   	});
    $self->push($gband);
	
    my $gband = new Bio::EnsEMBL::Glyph::Rect({
    	'x'      => $self->{'container'}->_global_start() * $vc2chr,
    	'y'      => 0,
    	'width'  => $len * $vc2chr,
    	'height' => 14,
    	'bordercolour' => $red,
		'absolutey' => 1,
   	});
    $self->push($gband);
	#print STDERR "Focus: ", int($self->{'container'}->_global_start()* $vc2chr), " width: ", int($len * $vc2chr), "\n";
}


1;
