package Bio::EnsEMBL::GlyphSet::gene;
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
    my ($this, $VirtualContig, $Config) = @_;

	return unless ($this->strand() == -1);
    my $y          = 0;
    my $h          = 8;
    my $highlights = $this->highlights();

    my @bitmap      = undef;
    my ($im_width, $im_height) = $Config->dimensions();
    my $bitmap_length = $VirtualContig->length();

	my @vg = $VirtualContig->get_all_VirtualGenes();

    foreach my $vg (@vg) {
		my $vgid = $vg->gene->id();
		my $vgstart = $vg->start();
		my $vgend = $vg->end();
		my $gstrand = $vg->strand();
		my $colour;
		if ($vg->gene->is_known()){
    		$colour = $Config->get($Config->script(),'gene','known');
		} else {
    		$colour = $Config->get($Config->script(),'gene','unknown');
		}
		my $rect = new Bio::EnsEMBL::Glyph::Rect({
			'x'        => $vgstart,
			'y'        => $y,
			'width'    => $vgend - $vgstart,
			'height'   => $h,
			'colour'   => $colour,
			'absolutey' => 1,
		});

    	#bump-nology!
    	###################################################
    	my $bump_start = $rect->x();
    	if ($bump_start < 0){$bump_start = 0};

    	my $bump_end = $bump_start + ($rect->width());
    	next if $bump_end > $bitmap_length;
    	my $row = &Bump::bump_row(      
            $bump_start,
            $bump_end,
            $bitmap_length,
            \@bitmap
    	);

    	next if $row > $Config->get($Config->script(), 'gene', 'dep');
    	###################################################

    	$rect->y($rect->y() + (1.5 * $row * $h));
		#print STDERR "Pushing gene on row $row on strand $gstrand\n";
    	$this->push($rect);
    }
}

1;
