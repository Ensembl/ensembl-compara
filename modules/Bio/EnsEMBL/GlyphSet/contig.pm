package Bio::EnsEMBL::GlyphSet::contig;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Poly;
use Bio::EnsEMBL::Glyph::Text;
use ColourMap;

sub _init {
    my ($self, $VirtualContig, $Config) = @_;
	my $col   = undef;
	my $cmap  = new ColourMap;
	my $col1  = $cmap->id_by_name('contigblue1');
	my $col2  = $cmap->id_by_name('contigblue2');
	my $col3  = $cmap->id_by_name('black');
	my $white  = $cmap->id_by_name('white');

	my @map_contigs = $VirtualContig->_vmap->each_MapContig();
	my $start = $map_contigs[0]->start();
	my $end   = $map_contigs[-1]->end();
	my $tot_width = $end - $start;
	my $ystart = 75;

	my ($im_width, $im_height) = $Config->dimensions();

	my $gline = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      => 1,
	    	'y'      => $ystart+7,
	    	'width'  => $im_width,
	    	'height' => 0,
	    	'colour' => $cmap->id_by_name('grey1'),
			'absolutey' => 1,
			'absolutex' => 1,
	});
	$self->push($gline);

	my $i = 0;
	foreach my $temp_rawcontig ( @map_contigs ) {
		if($i%2 == 0){
			$col = $col2;
		} else {
			$col = $col1;
		}
		$i++;
		my $glyph = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      => $temp_rawcontig->start,
	    	'y'      => $ystart+2,
	    	'width'  => $temp_rawcontig->end - $temp_rawcontig->start,
	    	'height' => 10,
	    	#'id'     => $temp_rawcontig->contig->id(),
	    	'colour' => $col,
			'absolutey'  => 1,
			'zmenu' => {
				'caption' => $temp_rawcontig->contig->id(),
				'foo'     => 'foo2',
			},
		});
		$self->push($glyph);
		#print STDERR "Contig!\n";

		my ($w,$h) = $Config->texthelper->px2bp('Tiny');
		my $text = $temp_rawcontig->contig->id();
		my $bp_textwidth = $w * length($text) +2;
		unless ($bp_textwidth > ($temp_rawcontig->end - $temp_rawcontig->start)){
			my $tglyph = new Bio::EnsEMBL::Glyph::Text({
	    		'x'      => $temp_rawcontig->start + int(($temp_rawcontig->end - $temp_rawcontig->start)/2) - ($bp_textwidth)/2,
	    		'y'      => $ystart+4,
				'font'   => 'Tiny',
	    		'colour' => $white,
				'text'   => $text,
				'absolutey'  => 1,
			});
			$self->push($tglyph);
		}
    }

	my $gline = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      => 0,
	    	'y'      => $ystart,
	    	'width'  => $im_width,
	    	'height' => 0,
	    	'colour' => $col3,
		'absolutey'  => 1,
		'absolutex'  => 1,
	});
	$self->push($gline);

	my $gline = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      => 0,
	    	'y'      => $ystart+14,
	    	'width'  => $im_width,
	    	'height' => 0,
	    	'colour' => $col3,
		'absolutey'  => 1,
		'absolutex'  => 1,
	});
	$self->push($gline);

	my $gtriag;

	$gtriag = new Bio::EnsEMBL::Glyph::Poly({
		'points'       => [$im_width-10,$ystart-4, $im_width-10,$ystart, $im_width,$ystart],
	    'colour'       => $col3,
		'absolutex'    => 1,
		'absolutey'    => 1,
	});
	$self->push($gtriag);

	$gtriag = new Bio::EnsEMBL::Glyph::Poly({
		'points'       => [0,$ystart+14, 10,$ystart+14, 10,$ystart+18],
	    'colour'       => $col3,
		'absolutex'    => 1,
		'absolutey'    => 1,
	});
	$self->push($gtriag);


	my $tick;
	my $interval = int($im_width/10);
	for (my $i=1; $i <=9; $i++){
		my $pos = $i * $interval;
		# the forward strand ticks
		$tick = new Bio::EnsEMBL::Glyph::Rect({
	    		'x'      => 0 + $pos,
	    		'y'      => $ystart-2,
	    		'width'  => 0,
	    		'height' => 1,
	    		'colour' => $col3,
			'absolutey'  => 1,
			'absolutex'  => 1,
		});
		$self->push($tick);
		# the reverse strand ticks
		$tick = new Bio::EnsEMBL::Glyph::Rect({
	    		'x'      => $im_width - $pos,
	    		'y'      => $ystart+15,
	    		'width'  => 0,
	    		'height' => 1,
	    		'colour' => $col3,
			'absolutey'  => 1,
			'absolutex'  => 1,
		});
		$self->push($tick);
	}
 	# The end ticks
	$tick = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      => 0,
	    	'y'      => $ystart-2,
	    	'width'  => 0,
	    	'height' => 1,
	    	'colour' => $col3,
		'absolutey'  => 1,
		'absolutex'  => 1,
	});
	$self->push($tick);
	# the reverse strand ticks
	$tick = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      => $im_width - 1,
	    	'y'      => $ystart+15,
	    	'width'  => 0,
	    	'height' => 1,
	    	'colour' => $col3,
		'absolutey'  => 1,
		'absolutex'  => 1,
	});
	$self->push($tick);
}



1;
