package Bio::EnsEMBL::GlyphSet::extgene;
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

	my @eg = $VirtualContig->get_all_ExternalGenes(); 
	my $colour = $Config->get($Config->script(),'extgene','col');
	my $rect;

    foreach my $gene (@eg) {
    	foreach my $trans ($gene->each_Transcript()) {

			my $start = $trans->start_exon()->start();
			my $end = $trans->end_exon()->end();
			my $strand = $trans->start_exon()->strand();
			my $id = $gene->id();

			$rect = new Bio::EnsEMBL::Glyph::Rect({
				'x'        => $start,
				'y'        => $y,
				'width'    => $end - $start,
				'height'   => $h,
				'colour'   => $colour,
				'absolutey' => 1,
			});

			print STDERR "Gene : $id\n";

    	}

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

    	next if $row > $Config->get($Config->script(), 'extgene', 'dep');
    	###################################################

    	$rect->y($rect->y() + (1.5 * $row * $h));
    	$this->push($rect);

	}
}

1;
