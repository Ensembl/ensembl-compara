package Bio::EnsEMBL::GlyphSet::chr_band;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use SiteDefs;

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $chr;
    eval {
        $chr = $self->{'container'}->_chr_name();
    };
    $chr = $@ ? "Chromosome" : "Chr $chr";
    my $label = new Bio::EnsEMBL::Glyph::Text({
    	'text'      => "$chr band",
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

    my $col    = undef;
    my $config = $self->{'config'};
    my $cmap   = $config->colourmap();
    my $white  = $cmap->id_by_name('white');
    my $black  = $cmap->id_by_name('black');
 
    my %COL = ();
    $COL{'gpos100'} = $cmap->id_by_name('black'); #add_rgb([200,200,200]);
    $COL{'gpos75'}  = $cmap->id_by_name('grey3'); #add_rgb([210,210,210]);
    $COL{'gpos50'}  = $cmap->id_by_name('grey2'); #add_rgb([230,230,230]);
    $COL{'gpos25'}  = $cmap->id_by_name('grey1'); #add_rgb([240,240,240]);
    $COL{'gpos'}    = $black; #add_rgb([240,240,240]);
    $COL{'gvar'}    = $cmap->add_rgb([222,220,220]);
    $COL{'gneg'}    = $white;
    $COL{'acen'}    = $cmap->id_by_name('slategrey');
    $COL{'tip'}     = $cmap->id_by_name('slategrey');
    $COL{'stalk'}   = $cmap->id_by_name('slategrey');
    
    my $im_width = $self->{'config'}->image_width();
    my ($w,$h) = $self->{'config'}->texthelper->px2bp('Tiny');
    
    my $prev_end = 0;
    my $i = 0;
    # fetch the chromosome bands that cover this VC.
    my @bands = $self->{'container'}->fetch_karyotype_band_start_end();
    my $min_start;
    my $max_end; 
    foreach my $band (reverse @bands){
	my $chr = $band->chromosome();
	my $bandname = $band->name();
	#print STDERR "BAND $i ($chr, $bandname)\n";
	
	my $band2 = $self->{'container'}->fetch_karyotype_band_by_name($chr,$bandname);
	my $start = $band2->start();
	my $end = $band2->end();
	my $stain = $band2->stain();
	
	my $vc_band_start = $start - $self->{'container'}->_global_start();
	$vc_band_start    = 0 if ($vc_band_start < 0);
	
	my $vc_band_end   = $end - $self->{'container'}->_global_start();
	$vc_band_end      =  $self->{'container'}->length() if ($vc_band_end > $self->{'container'}->length());
	
        my $min_start = $vc_band_start if(!defined $min_start || $min_start > $vc_band_start); 
        my $max_end   = $vc_band_end   if(!defined $max_end   || $max_end   < $vc_band_end); 
    	my $gband = new Bio::EnsEMBL::Glyph::Rect({
	    'x'      => $vc_band_start,
	    'y'      => 0,
	    'width'  => $vc_band_end - $vc_band_start,
	    'height' => 10,
	    'colour' => $COL{$stain},
#    		'bordercolour' => $black,
	    'absolutey' => 1,
	});
    	$self->push($gband);
	
	my $fontcolour;
	# change label colour to white if the chr band is black, else use black...
	if ($stain eq "gpos100" || $stain eq "gpos" || $stain eq "acen" || $stain eq "stalk" || $stain eq "gpos75" || $stain eq "tip"){
	    $fontcolour = $white;
	} else {
	    $fontcolour = $black;
	}
	my $bp_textwidth = $w * length($bandname);
	# only add the lable if the box is big enough to hold it...
	unless ($bp_textwidth > ($vc_band_end - $vc_band_start) || $stain eq "tip"|| $stain eq "acen"){
	    my $tglyph = new Bio::EnsEMBL::Glyph::Text({
		'x'      => $vc_band_start + int(($vc_band_end - $vc_band_start)/2 - ($bp_textwidth)/2),
		'y'      => 2,
		'font'   => 'Tiny',
		'colour' => $fontcolour,
		'text'   => $bandname,
		'absolutey'  => 1,
	    });
	    $self->push($tglyph);
	}
	
    	my $gband = new Bio::EnsEMBL::Glyph::Rect({
	    'x'      => $min_start,
	    'y'      => 0,
	    'width'  => $max_end - $min_start,
	    'height' => 10,
	    'bordercolour' => $black,
	    'absolutey' => 1,
	});
    	$self->push($gband);
	
	#print STDERR "VCSTART: $vc_band_start, VCEND: $vc_band_end, WIDTH: ",$vc_band_end - $vc_band_start, "\n";
	#print STDERR "VC length: ", $self->{'container'}->length(), "\n";
	#print STDERR "Stain: $stain = ", $COL{$stain}, "\n";
	
	$i++;
    }
}

1;
