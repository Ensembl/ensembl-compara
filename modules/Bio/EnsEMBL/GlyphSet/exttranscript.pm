package Bio::EnsEMBL::GlyphSet::exttranscript;
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

    my $y          = 0;
    my $h          = 8;
    my $highlights = $this->highlights();
    my @bitmap     = undef;
    my ($im_width, $im_height) = $Config->dimensions();
    my $bitmap_length = $VirtualContig->length();
    my $colour = $Config->get($Config->script(),'extgene','col');

    my @vg = $VirtualContig->get_all_ExternalGenes();
    GENE: for my $vg (@vg) {
		my $vgid = $vg->id();
    	my $hi_colour = $Config->get($Config->script(),'extgene','hi') if(defined $highlights && $highlights =~ /\|$vgid\|/);

		TRANSCRIPT: for my $transcript ($vg->each_Transcript()) {

	    	#########
	    	# test transcript strand
	    	#
	    	my $tstrand = $transcript->start_exon()->strand();
	    	next TRANSCRIPT if($tstrand != $this->strand());


	    	my $Composite = new Bio::EnsEMBL::Glyph::Composite({
			'id'     => $transcript->id(),
			'colour' => $hi_colour,
			'zmenu'  => {
		    	'caption'  => $transcript->id(),
		    	'01:kung'     => 'opt1',
		    	'02:foo'      => 'opt2',
		    	'03:fighting' => 'opt3'
			},
	    	});

	    	my $previous_endx = undef;
	    	my @exons = $transcript->each_Exon();

	    	#########
	    	# it appears as though we've still got to do a sort here because there are still
	    	# some wacky transcripts around on the reverse strand but with their exons out of order.
	    	# (see chr9 bps 5110000 to 5130000 for example)
	    	#
	    	@exons = sort { $a->start() <=> $b->start() } @exons;

	    	#########
	    	# as soon as the wacky transcript problem (above) is fixed, 
	    	# just reverse @exons for the reverse strand, which is faster than a re-sort
	    	#
	#	    @exons = reverse @exons if($tstrand == -1);

	    	EXON: for my $exon (@exons) {

			next if ($exon->seqname() ne $VirtualContig->id()); # clip off virtual gene exons not on this VC

			my $x = $exon->start();
			my $w = $exon->end() - $x;
			next if($x < 0);

			my $rect = new Bio::EnsEMBL::Glyph::Rect({
		    	'x'        => $x,
		    	'y'        => $y,
		    	'width'    => $w,
		    	'height'   => $h,
		    	'colour'   => $colour,
		    	'absolutey' => 1,
			});

			my $intron = new Bio::EnsEMBL::Glyph::Intron({
		    	'x'        => $previous_endx,
		    	'y'        => $y,
		    	'width'    => ($x - $previous_endx),
		    	'height'   => $h,
		    	'id'       => $exon->id(),
		    	'colour'   => $colour,
		    	'absolutey' => 1,
		    	'strand'    => $tstrand,
			}) if(defined $previous_endx);

			$Composite->push($rect);
			$Composite->push($intron);

			$previous_endx = $x+$w;
	    	}

	    	#########
	    	# bump it baby, yeah!
	    	# bump-nology!
	    	#
	    	my $bump_start = $Composite->x();
	    	$bump_start = 0 if ($bump_start < 0);

	    	my $bump_end = $bump_start + ($Composite->width());
	    	next if $bump_end > $bitmap_length;
	    	my $row = &Bump::bump_row(      
				    	  $bump_start,
				    	  $bump_end,
				    	  $bitmap_length,
				    	  \@bitmap
	    	);

	    	#########
	    	# skip this row if it's bumped off the bottom
	    	#
	    	next if $row > $Config->get($Config->script(), 'transcript', 'dep');

	    	#########
	    	# shift the composite container by however much we're bumped
	    	#
	    	$Composite->y($Composite->y() + (1.5 * $row * $h * -$tstrand));
	    	$this->push($Composite);
		}
    }
}

1;
