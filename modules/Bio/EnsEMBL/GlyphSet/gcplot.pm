package Bio::EnsEMBL::GlyphSet::gcplot;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

sub _init {
    my ($self, $VirtualContig, $Config) = @_;

    return unless ($self->strand() == -1);
    my $h               = 0;
    my $highlights      = $self->highlights();
    my $feature_colour 	= $Config->get($Config->script(),'gcplot','hi');
    my $alt_colour 	    = $Config->get($Config->script(),'gcplot','low');
	my $cmap 			= $Config->colourmap();
	#my $black 			= $cmap->add_rgb([0,0,0]);
	#my $red 			= $cmap->add_rgb([255,0,0]);
	my $black 			= $cmap->id_by_name('black');
	my $red 			= $cmap->id_by_name('red');
	
	#my $divlen = 20000;
	my $im_width = $Config->image_width();
	#if ($divlen > 400) { $divlen = 400;}
		
	#my $divs = int(($VirtualContig->length())/$divlen);
	my $divs = int($im_width/5);
	my $divlen = int($VirtualContig->length()/$divs);
	
	#print STDERR "Divs = $divs\n";
	my $seq = $VirtualContig->seq();
	my @gc = ();
	my $min = 100;
	my $max = 0;
	
	for (my $i=0; $i<$divs; $i++){
		#print STDERR "Div: $i\n";
		my $subseq = substr($seq, $i*$divlen, $divlen);
		#$subseq =~ s/N//igo;
		my $G = $subseq =~ tr/G/G/;
		my $C = $subseq =~ tr/C/C/;
		my $percent = ($G+$C)/length($subseq);
		#print STDERR "$percent\n";
		if ($percent < $min){ $min = $percent;}
		if ($percent > $max){ $max = $percent;}
		push (@gc, $percent);
	}
		
	my $line = new Bio::EnsEMBL::Glyph::Line({
	    'x'      	=> 0,
	    'y'      	=> 10, # 50% point for line
	    'width'  	=> $VirtualContig->length(),
	    'height' 	=> 0,
	    'colour' 	=> $red,
		'absolutey' => 1,
		'dotted'  	=> 1,
	});
	$self->push($line);
		
	my $range = $max - $min;
	#print STDERR "Min   = $min\n";
	#print STDERR "Max   = $max\n";
	#print STDERR "Range = $range\n";
	
	if(0){
		for (my $i=0; $i<$divs; $i++){	
			#print STDERR "Current bar = $gc[$i]\n";

			my $tick = new Bio::EnsEMBL::Glyph::Rect({
	    		'x'      => $i * $divlen,
	    		'y'      => 20 - int(20 * $gc[$i]),
	    		'width'  => $divlen,
	    		'height' => int(20 * $gc[$i]),
	    		'bordercolour' => $alt_colour,
				'absolutey'  => 1,
			});
			if ($gc[$i] > 0.5) { 
				print STDERR "\tover bar ==>  $gc[$i]\n";
				$tick->{'bordercolour'} = $feature_colour;
			}
			$self->push($tick);
		}
	}
	
	for (my $i=0; $i<$divs; $i++){	
		#print STDERR "Current bar = $gc[$i]\n";

		my $tick = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      => $i * $divlen,
	    	'y'      => int(10 * $gc[$i]),
	    	'width'  => $divlen,
	    	'height' => 10 - int(10 * $gc[$i]),
	    	'bordercolour' => $alt_colour,
			'absolutey'  => 1,
		});
		if ($gc[$i] > 0.5) { 
			print STDERR "\tover bar ==>  $gc[$i]\n";
			$tick->{'bordercolour'} = $feature_colour;
		}
		$self->push($tick);
	}
	
	my $line = new Bio::EnsEMBL::Glyph::Line({
	    'x'      => 0,
	    'y'      => 20,
	    'width'  => $VirtualContig->length(),
	    'height' => 0,
	    'colour' => $black,
		'absolutey'  => 1,
	});
	$self->push($line);
		
    my $fontname = "Tiny";
	my $text = "% GC by $divlen bp window [dotted line shows 50%]";
	#my $text = "% GC by $divlen bp window";
	my ($w,$h) = $Config->texthelper->px2bp($fontname);
	my $bp_textwidth = $w * length($text) * 1.1; # add 10% for scaling text
	my $tglyph = new Bio::EnsEMBL::Glyph::Text({
		'x'      	=> $VirtualContig->length()/2 - $bp_textwidth/2,
		'y'      	=> 22,
		'height'    => $Config->texthelper->height($fontname),
		'font'   	=> $fontname,
		'colour' 	=> $feature_colour,
		'text'   	=> $text,
		'absolutey' => 1,
	});
	$self->push($tglyph);

}

1;

