package Bio::EnsEMBL::GlyphSet::sptr;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Composite;
use Bio::EnsEMBL::Glyph::Poly;

sub _init {
    my ($this, $VirtualContig, $Config) = @_;

    my $y          = 0;
    my $h          = 8;
    my $highlights = $this->highlights();

    #########
    # set colour for transcripts and test if we're highlighted or not
    # 
    my $colour = $Config->get('transview','sptr','col');

    GENE: for my $vg ($VirtualContig->get_all_VirtualGenes('evidence')) {

	my $vgid = $vg->gene->id();

	TRANSCRIPT: for my $transcript ($vg->gene->each_Transcript()) {

	    #########
	    # test transcript strand
	    #
	    my $tstrand = $transcript->start_exon()->strand();
	    next TRANSCRIPT if($tstrand != $this->strand());

print STDERR qq(finding $colour sptr features for $transcript on strand $tstrand\n);

	    EXON: for my $exon ($transcript->each_Exon()) {

		FEATURE: for my $feature ($exon->each_Supporting_Feature()) {

print STDERR qq(found feature $feature\n);

		    my $x = $feature->start();
		    my $w = $feature->end() - $x;

		    my $rect = new Bio::EnsEMBL::Glyph::Rect({
			'x'        => $x,
			'y'        => $y,
			'width'    => $w,
			'height'   => $h,
			'id'       => $feature->id(),
			'colour'   => $colour,
			'zmenu' => {
			    'caption' => qq(swissprot trEMBL),
			},
		    });

		    $this->push($rect);
		}
	    }
	    #########
	    # replace this with bumping!
	    #
	    $y+=$h;
	}
    }
}

1;
