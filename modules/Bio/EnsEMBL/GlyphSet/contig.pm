package Bio::EnsEMBL::GlyphSet::contig;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;

sub _init {
    my ($this, $VirtualContig, $Config) = @_;

    for(my $i = 0; $i<1000; $i+=100) {
	my $glyph = new Bio::EnsEMBL::Glyph::Rect({
	    'x'      => $i,
	    'y'      => 0,
	    'width'  => 20,
	    'height' => 8,
	    'id'     => qq(ctg$i),
	    #########
	    # evil:
	    #
	    'col'    => $Config->get('contigviewtop', 'contig', 'col'),
	});

	#########
	# can either use access method:
	# $this->push($glyph);
	# or do the equivalent:
	#
	push @{$this->{'glyphs'}}, $glyph;
    }
}
1;
