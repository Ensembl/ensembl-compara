package Bio::EnsEMBL::GlyphSet::prot_scalebar;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub init_label {
    my ($this) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Scale (aa)',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($self) = @_;
	
    my $h                     = 0;
    my $fontname              = "Tiny";
    my $Config        	      = $self->{'config'};
    my $fontheight 	      = $Config->texthelper->height($fontname),
    my $fontwidth_bp 	      = $Config->texthelper->width($fontname),
    my ($fontwidth,$dontcare) = $Config->texthelper->px2bp($fontname),
	
    my $feature_colour 	      = $Config->get('prot_scalebar','col');
    my $len                   = $self->{'container'}->length();
    my $divs                  = set_scale_division($len);
    
    my $glyph = new Bio::EnsEMBL::Glyph::Rect({
	'x'         => 0,
	'y'         => 4,
	'width'     => $len,
	'height'    => $h,
	'colour'    => $feature_colour,
	'absolutey' => 1,
    });
    $self->push($glyph);
    
    my $last_end = 0;
    for (my $i=0;$i<int($len/$divs); $i++){
	
	my $tick = new Bio::EnsEMBL::Glyph::Rect({
	    'x'         => $i * $divs,
	    'y'         => 4,
	    'width'     => 0,
	    'height'    => 2,
	    'colour'    => $feature_colour,
	    'absolutey' => 1,
	});
	$self->push($tick);
	
	my $text = $i * $divs;
	my $tglyph = new Bio::EnsEMBL::Glyph::Text({
	    'x'      	=> $i * $divs,
	    'y'      	=> 8,
	    'height'	=> $fontheight,
	    'font'   	=> $fontname,
	    'colour' 	=> $feature_colour,
	    'text'   	=> $text,
	    'absolutey' => 1,
	});
	$self->push($tglyph);
    }
    
    # label first tick
    my $text = "0";
    my $tglyph = new Bio::EnsEMBL::Glyph::Text({
	'x'      	=> 0,
	'y'      	=> 8,
	'height'	=> $fontheight,
	'font'   	=> $fontname,
	'colour' 	=> $feature_colour,
	'text'   	=> $text,
	'absolutey' => 1,
    });
    $self->push($tglyph);
    
    my $im_width = $Config->image_width();
    $text = $len;
    
    # label last tick
    my $endglyph = new Bio::EnsEMBL::Glyph::Text({
	'x'      	=> $im_width -(length("$text ")*$fontwidth_bp),
	'y'      	=> 8,
	'height'	=> $fontheight,
	'font'   	=> $fontname,
	'colour' 	=> $feature_colour,
	'text'   	=> $text,
	'absolutex'  => 1,
	'absolutey' => 1,
    });
    $self->push($endglyph);
    
    # add last tick
    my $im_width = $Config->image_width();
    my $tick = new Bio::EnsEMBL::Glyph::Rect({
	'x'          => $im_width,
	'y'          => 4,
	'width'      => 0,
	'height'     => 2,
	'colour'     => $feature_colour,
	'absolutex'  => 1,
	'absolutey'  => 1,
    });
    $self->push($tick);
}

##############################################################################
sub set_scale_division {
    my ($full_length) = @_;
    
    my $num_of_digits = length( int( $full_length / 10 ) );
    $num_of_digits--;

    my $division = 10**$num_of_digits;
    my $first_division = $division;

    my $num_of_divs = int( $full_length / $division );
    my $i=2;

    until ( $num_of_divs < 12 ) {
	$division = $first_division * $i;
	$num_of_divs = int( $full_length / $division );
	$i += 2;
    }

    return $division;
} 



##############################################################################
sub bp_to_nearest_unit_by_divs {
    my ($bp,$divs) = @_;

    if (!defined $divs){
	return bp_to_nearest_unit ($bp,0);
    }

    my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
    my $value = $divs / ( 10 ** ( $power_ranger * 3 ) ) ;

    my $dp = 0;
    if ($value < 1){
	$dp = length ($value) - 2;		# 2 for leading "0."
    }
      
    return bp_to_nearest_unit ($bp,$dp);
}



##############################################################################
sub bp_to_nearest_unit {
    my ($bp,$dp) = @_;
    $dp = 1 unless defined $dp;
    
    my @units = qw( aa aa aa aa aa );
    
    my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
    my $unit = $units[$power_ranger];
    my $unit_str;

    my $value = int( $bp / ( 10 ** ( $power_ranger * 3 ) ) );
      
    if ( $unit ne "bp" ) {
	$unit_str = sprintf( "%.${dp}f%s", $bp / ( 10 ** ( $power_ranger * 3 ) ), " $unit" );
    } else {
	$unit_str = "$value $unit";
    }
    return $unit_str;
}


1;
