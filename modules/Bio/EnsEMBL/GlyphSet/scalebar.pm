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
    my $Config        = $self->{'config'};

    #return unless ($self->strand() == -1);
    my $h          = 0;
    my $highlights = $self->highlights();

    my $fontname = "Tiny";
    my $fontheight = $Config->texthelper->height($fontname),
    my $fontwidth_bp = $Config->texthelper->width($fontname),
    my ($fontwidth,$dontcare) = $Config->texthelper->px2bp($fontname),
    my $cmap  = new ColourMap;
    my $black = $cmap->id_by_name('black');
	my $chr = $self->{'container'}->_chr_name();
	
    my $feature_colour 	= $Config->get($Config->script(),'scalebar','col');
    my $subdivs = $Config->get($Config->script(),'scalebar','subdivs');
    my $abbrev = $Config->get($Config->script(),'scalebar','abbrev');

    my $len = $self->{'container'}->length();
    my $global_start = $self->{'container'}->_global_start();
    my $global_end = $self->{'container'}->_global_end();
	my $global_offset = int(($global_end - $global_start)/2);
	#print STDERR "VC half length = $global_offset\n";
	#print STDERR "VC start = $global_start\n";
	#print STDERR "VC end = $global_end\n";

    my $divs = 0;
    $divs = set_scale_division($len);
    
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
			my $new_start  = $interval_middle - $global_offset;
			my $new_end    = $interval_middle + $global_offset;

			my $zoom_out_new_start  = $interval_middle - 2 * $global_offset;
			my $zoom_out_new_end    = $interval_middle + 2 * $global_offset;

			my $zoom_in_new_start  = $interval_middle - int($global_offset/2);
			my $zoom_in_new_end    = $interval_middle + int($global_offset/2);

    		my $url = "$ENV{'SCRIPT_NAME'}?chr=$chr";
			$url .= "&vc_start=";
			$url .= $new_start;
			$url .= "&vc_end=";
			$url .= $new_end;
    		my $url_zoom_out = "$ENV{'SCRIPT_NAME'}?chr=$chr";
			$url_zoom_out .= "&vc_start=";
			$url_zoom_out .= $zoom_out_new_start;
			$url_zoom_out .= "&vc_end=";
			$url_zoom_out .= $zoom_out_new_end;
    		my $url_zoom_in = "$ENV{'SCRIPT_NAME'}?chr=$chr";
			$url_zoom_in .= "&vc_start=";
			$url_zoom_in .= $zoom_in_new_start;
			$url_zoom_in .= "&vc_end=";
			$url_zoom_in .= $zoom_in_new_end;
			
			#print STDERR "URL: $url\n";
			
			my $interval = new Bio::EnsEMBL::Glyph::Rect({
	    		'x'         => $last_end,
	    		'y'         => 4,
	    		'width'     => ($i * $divs) - $last_end,
	    		'height'    => 15,
	    		'colour'    => 'transparent',
	    		'absolutey' => 1,
            	'zmenu'     => { 
					'caption' 						=> "Navigation",
					'Centre on this scale interval' => $url, 
					'Zoom in (x2)' 					=> $url_zoom_in, 
					'Zoom out (x0.5)' 				=> $url_zoom_out, 
				},
			});
			$self->push($interval);
			$last_end = $i * $divs;
		}
    }
	
	# Add the last recentering imagemap-only glyphs
	if ($Config->script() eq "contigviewbottom"){
		my $interval_middle = $global_end - int($divs/2);
		my $new_start  = $interval_middle - $global_offset;
		my $new_end    = $interval_middle + $global_offset;

		my $zoom_out_new_start  = $interval_middle - 2 * $global_offset;
		my $zoom_out_new_end    = $interval_middle + 2 * $global_offset;

		my $zoom_in_new_start  = $interval_middle - int($global_offset/2);
		my $zoom_in_new_end    = $interval_middle + int($global_offset/2);

    	my $url = "$ENV{'SCRIPT_NAME'}?chr=$chr";
		$url .= "&vc_start=";
		$url .= $new_start;
		$url .= "&vc_end=";
		$url .= $new_end;
    	my $url_zoom_out = "$ENV{'SCRIPT_NAME'}?chr=$chr";
		$url_zoom_out .= "&vc_start=";
		$url_zoom_out .= $zoom_out_new_start;
		$url_zoom_out .= "&vc_end=";
		$url_zoom_out .= $zoom_out_new_end;
    	my $url_zoom_in = "$ENV{'SCRIPT_NAME'}?chr=$chr";
		$url_zoom_in .= "&vc_start=";
		$url_zoom_in .= $zoom_in_new_start;
		$url_zoom_in .= "&vc_end=";
		$url_zoom_in .= $zoom_in_new_end;

		#print STDERR "URL: $url\n";

		my $interval = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'         => $last_end,
	    	'y'         => 4,
	    	'width'     => $len - $last_end,
	    	'height'    => 15,
	    	'colour'    => 'transparent',
	    	'absolutey' => 1,
            'zmenu'     => { 
				'caption' => "Navigation",
				'Centre on this scale interval' => $url, 
				'Zoom in (x2)' 					=> $url_zoom_in, 
				'Zoom out (x0.5)' 				=> $url_zoom_out, 
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
    }
    else {
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
    }else{
	$unit_str = "$value $unit";
    }
    return $unit_str;
}


1;
