package Bio::EnsEMBL::GlyphSet::scalebar;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub _init {
    my ($self) = @_;
    #return unless ($self->strand() == -1);

    my $Config         = $self->{'config'};
    my $Container      = $self->{'container'};
    my $h              = 0;
    my $highlights     = $self->highlights();

    my $fontname       = "Tiny";
    my $fontwidth_bp   = $Config->texthelper->width($fontname),
    my ($fontwidth,
	$fontheight)       = $Config->texthelper->px2bp($fontname),
    my $black          = $Config->colourmap->id_by_name('black');
    my $highlights     = join('|',$self->highlights());
    $highlights        = "&highlight=$highlights" if($highlights);
    my $feature_colour = $Config->get('scalebar', 'col');
    my $subdivs        = $Config->get('scalebar', 'subdivs');
    my $max_num_divs   = $Config->get('scalebar', 'max_divisions') || 12;
    my $abbrev         = $Config->get('scalebar', 'abbrev');

    my $chr            = $Container->_chr_name();
    my $len            = $Container->length();
    my $global_start   = $Container->_global_start();
    my $global_end     = $Container->_global_end();
    my $global_offset  = int(($global_end - $global_start)/2);

    #print STDERR "VC half length = $global_offset\n";
    #print STDERR "VC start = $global_start\n";
    #print STDERR "VC end = $global_end\n";

    my $divs = set_scale_division($len, $max_num_divs) || 0;
    
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

	if ($Config->script() eq "contigviewbottom"){
	    
	    # Add the recentering imagemap-only glyphs
	    my $interval_middle = $global_start + ($i * $divs) + int($divs/2) - $divs;
	    #print STDERR "URL: $url\n";
	    
	    my $interval = new Bio::EnsEMBL::Glyph::Rect({
		'x'         => $last_end,
		'y'         => 4,
		'width'     => ($i * $divs) - $last_end,
		'height'    => 15,
		'colour'    => 'transparent',
		'absolutey' => 1,
        'zmenu'     => { 
		    'caption' 			    => "Navigation",
		    '01:Zoom in (x10)' 	       	=> &zoom_URL($chr, $interval_middle, $global_offset, 10, $highlights),
		    '02:Zoom in (x5)' 	       	    => &zoom_URL($chr, $interval_middle, $global_offset, 5, $highlights),
			'03:Zoom in (x2)' 	       	    => &zoom_URL($chr, $interval_middle, $global_offset, 2, $highlights),
			'04:Centre on this scale interval' => &zoom_URL($chr, $interval_middle, $global_offset, 1, $highlights), 
		    '05:Zoom out (x0.5)' 		    => &zoom_URL($chr, $interval_middle, $global_offset, 0.5, $highlights), 
		    '06:Zoom out (x0.2)' 		    => &zoom_URL($chr, $interval_middle, $global_offset, 0.2, $highlights), 
			'07:Zoom out (x0.1)' 		    => &zoom_URL($chr, $interval_middle, $global_offset, 0.1, $highlights) 		
			},
	    });
	    $self->push($interval);
	    $last_end = $i * $divs;
	}
    }
	
    # Add the last recentering imagemap-only glyphs
    if ($Config->script() eq "contigviewbottom"){
	    my $interval_middle = $global_end - int($divs/2);

	my $interval = new Bio::EnsEMBL::Glyph::Rect({
	    'x'         => $last_end,
	    'y'         => 4,
	    'width'     => $len - $last_end,
	    'height'    => 15,
	    'colour'    => 'transparent',
	    'absolutey' => 1,
        'zmenu'     => { 
			'caption' => "Navigation",
		    'Zoom in (x10)' 	       	=> &zoom_URL($chr, $interval_middle, $global_offset, 10, $highlights),
		    'Zoom in (x5)' 	       	    => &zoom_URL($chr, $interval_middle, $global_offset, 5, $highlights),
			'Zoom in (x2)' 	       	    => &zoom_URL($chr, $interval_middle, $global_offset, 2, $highlights),
			'Centre on this scale interval' => &zoom_URL($chr, $interval_middle, $global_offset, 1, $highlights), 
		    'Zoom out (x0.5)' 		    => &zoom_URL($chr, $interval_middle, $global_offset, 0.5, $highlights), 
		    'Zoom out (x0.2)' 		    => &zoom_URL($chr, $interval_middle, $global_offset, 0.2, $highlights), 
			'Zoom out (x0.1)' 		    => &zoom_URL($chr, $interval_middle, $global_offset, 0.1, $highlights) 		
 
	    },
	});
	$self->push($interval);
    }
    
    if ($subdivs && $len > 1000){
	# label each division
	for (my $i=0;$i<int($len/$divs); $i++){
	    my $text = int($i * $divs + $global_start);		
	    if ($abbrev){
		$text = bp_to_nearest_unit_by_divs(int($i * $divs + $global_start),$divs);		
	    }
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

    } else {
	# label first and last
	my $text = $global_start;
	if ($abbrev && $len >1000){
	    $text = bp_to_nearest_unit($global_start,2);
	}
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
	$text = $global_end;
	if ($abbrev && $len >1000){
	    $text = bp_to_nearest_unit($global_end,2);
	}
	
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
	
    }
	
    # last tick
    my $im_width = $Config->image_width();
    my $tick = new Bio::EnsEMBL::Glyph::Rect({
	'x'          => $im_width - 1,
	'y'          => 4,
	'width'      => 0,
	'height'     => 2,
	'colour'     => $feature_colour,
	'absolutex'  => 1,
	'absolutey'  => 1,
    });
    $self->push($tick);
}


sub set_scale_division {
    my ($full_length, $max_num_divs) = @_;

	$max_num_divs = $max_num_divs <1 ? 1 : $max_num_divs;

    my $num_of_digits = length( int( $full_length / 10 ) );
    $num_of_digits--;

    my $division = 10**$num_of_digits;
    my $first_division = $division;

    my $num_of_divs = int( $full_length / $division );
    my $i=2;
    until ( $num_of_divs < $max_num_divs ) {
	   $division = $first_division * $i;
	   $num_of_divs = int( $full_length / $division );
	   $i += 2;
    }

    return $division;
} 



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



sub bp_to_nearest_unit {
    my ($bp,$dp) = @_;
    $dp = 1 unless defined $dp;
    
    my @units = qw( bp Kb Mb Gb Tb );
    
    my $power_ranger = int( ( length( abs($bp) ) - 1 ) / 3 );
    my $unit = $units[$power_ranger];
    my $unit_str;

    my $value = int( $bp / ( 10 ** ( $power_ranger * 3 ) ) );
      
    if ( $unit ne "bp" ){
	$unit_str = sprintf( "%.${dp}f%s", $bp / ( 10 ** ( $power_ranger * 3 ) ), " $unit" );
    } else {
	$unit_str = "$value $unit";
    }
    return $unit_str;
}

sub zoom_URL {
	my( $chr, $interval_middle, $global_offset, $factor, $highlights ) = @_;
	my $start = int( $interval_middle - $global_offset / $factor);
	my $end   = int( $interval_middle + $global_offset / $factor);	
	return qq(/$ENV{'ENSEMBL_SPECIES'}/$ENV{'ENSEMBL_SCRIPT'}?chr=$chr&vc_start=$start&vc_end=$end$highlights);
}
1;
