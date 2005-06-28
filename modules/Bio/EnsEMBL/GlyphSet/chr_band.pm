package Bio::EnsEMBL::GlyphSet::chr_band;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;

my %SHORT = qw(
  chromosome Chr.
  supercontig S'ctg #' 
);

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $type = $self->{'container'}->coord_system->name();

    $type = $SHORT{lc($type)} || ucfirst( $type );

    my $species = '';
    if( $self->{'config'}->{'multi'} ) {
       $species = join '', map { substr($_,0,1) } split( /_/, $self->{'config'}->{'species'}),'.',' ';
    }
    my $chr = $self->{'container'}->seq_region_name();
    $chr = "$species$type $chr";

    my $label = new Sanger::Graphics::Glyph::Text({
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
    my $white  = 'white';
    my $black  = 'black';
 
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
    
    my $im_width = $self->{'config'}->image_width();
    my ($w,$h) = $self->{'config'}->texthelper->px2bp('Tiny');
    
    my $prev_end = 0;
    my $i = 0;
    # fetch the chromosome bands that cover this VC.
    my $bands = $self->{'container'}->get_all_KaryotypeBands();
    my $min_start;
    my $max_end; 
    foreach my $band (reverse @$bands){
	my $chr = $band->slice()->seq_region_name();
	my $bandname = $band->name();
	   $bandname =~ /(\d+)\w?/;
	my $band_no = $1;
	my $start = $band->start();
	my $end = $band->end();
	my $stain = $band->stain();
	
	my $vc_band_start = $start;
	$vc_band_start    = 0 if ($vc_band_start < 0);
	my $vc_band_end = $end;
	$vc_band_end      =  $self->{'container'}->length() if ($vc_band_end > $self->{'container'}->length());
	
        my $min_start = $vc_band_start if(!defined $min_start || $min_start > $vc_band_start); 
        my $max_end   = $vc_band_end   if(!defined $max_end   || $max_end   < $vc_band_end); 
    	my $gband = new Sanger::Graphics::Glyph::Rect({
	    'x'      => $vc_band_start -1 ,
	    'y'      => 0,
	    'width'  => $vc_band_end - $vc_band_start +1 ,
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
	    my $tglyph = new Sanger::Graphics::Glyph::Text({
		'x'      => $vc_band_start + int(($vc_band_end - $vc_band_start)/2 - ($bp_textwidth)/2),
		'y'      => 2,
		'font'   => 'Tiny',
		'colour' => $fontcolour,
		'text'   => $bandname,
		'absolutey'  => 1,
	    });
	    $self->push($tglyph);
	}

        my $vc_ajust = 1 - $self->{'container'}->start ;
        my $band_start = $band->{'start'} - $vc_ajust;
        my $band_end = $band->{'end'} - $vc_ajust;
    	my $gband = new Sanger::Graphics::Glyph::Rect({
	    'x'      => $min_start -1 ,
	    'y'      => 0,
	    'width'  => $max_end - $min_start + 1,
	    'height' => 10,
	    'bordercolour' => $black,
	    'absolutey' => 1,
            'zmenu' => {
              'caption' => "Band $bandname",
              "00:Zoom to width"  => "/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?l=$chr:$band_start-$band_end",
                }
        });
        foreach my $script (qw(contigview cytoview)) {
          next if $script eq $ENV{'ENSEMBL_SCRIPT'};
          $gband->{'zmenu'}{ "01:Display in $script" } = "/@{[$self->{container}{_config_file_name_}]}/$script?l=$chr:$band_start-$band_end";
        }	
	if( @{[$self->{container}{_config_file_name_}]} =~ /Anopheles_gambiae/i ){
          $gband->{'zmenu'}{ "02:View band diagram" } = "/@{[$self->{container}{_config_file_name_}]}/BACmap?chr=$chr;band=$band_no",
        }
    	$self->push($gband);
	$i++;
    }
}

1;
