package Bio::EnsEMBL::GlyphSet::contig;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Poly;
use ColourMap;

sub _init {
    my ($self, $VirtualContig, $Config) = @_;
	my $col   = undef;
	my $cmap  = new ColourMap;
	my $col1  = $cmap->id_by_name('contigblue1');
	my $col2  = $cmap->id_by_name('contigblue2');
	my $col3  = $cmap->id_by_name('black');

	my @map_contigs = $VirtualContig->_vmap->each_MapContig();
	my $start = $map_contigs[0]->start();
	my $end   = $map_contigs[-1]->end();
	my $tot_width = $end - $start;
	my $ystart = 50;

	my ($im_width, $im_height) = $Config->dimensions();

	my $gline = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      => 0,
	    	'y'      => $ystart+10,
	    	'width'  => $im_width,
	    	'height' => 0,
	    	'colour' => $cmap->id_by_name('grey1'),
		'absolutey' => 1,
		'absolutex' => 1,
	});
	$self->push($gline);

	my $i = 0;
	foreach my $temp_rawcontig ( @map_contigs ) {
		#print STDERR "Contig: ", $temp_rawcontig, "\n";
		#print STDERR "Contig start: ", $temp_rawcontig->start, "\n";
		#print STDERR "Contig end: ", $temp_rawcontig->end, "\n";
		if ($i%2 == 0) { 
			$col = $col1;
		} else { 
			$col = $col2;
		}
		$i++;
		my $glyph = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      => $temp_rawcontig->start,
	    	'y'      => $ystart+5,
	    	'width'  => $temp_rawcontig->end - $temp_rawcontig->start,
	    	'height' => 10,
	    	'id'     => $temp_rawcontig->contig->id(),
	    	'colour' => $col,
		'absolutey' => 1,
		'zmenu' => {
			'caption' => $temp_rawcontig->contig->id(),
			'foo'     => 'foo2',
		},
		});
		$self->push($glyph);
    }


	my $gline = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      => 0,
	    	'y'      => $ystart+2,
	    	'width'  => $im_width,
	    	'height' => 0,
	    	'colour' => $col3,
		'absolutey' => 1,
		'absolutex' => 1,
	});
	$self->push($gline);

	my $gline = new Bio::EnsEMBL::Glyph::Rect({
	    	'x'      => 0,
	    	'y'      => $ystart+18,
	    	'width'  => $im_width,
	    	'height' => 0,
	    	'colour' => $col3,
		'absolutey' => 1,
		'absolutex' => 1,
	});
	$self->push($gline);

	my $gtriag;

	$gtriag = new Bio::EnsEMBL::Glyph::Poly({
		'points'       => [$im_width-10,$ystart+18, $im_width,$ystart+18, $im_width-10,$ystart+28],
	    	'colour'       => $col3,
		'absolutex'    => 1,
		'absolutey'    => 1,
	});
	$self->push($gtriag);

	$gtriag = new Bio::EnsEMBL::Glyph::Poly({
		'points'       => [0,$ystart+2, 10,$ystart-8, 10,$ystart+2],
	    	'id'           => '',
	    	'colour'       => $col3,
		'absolutex'    => 1,
		'absolutey'    => 1,
	});
	$self->push($gtriag);
}

1;
