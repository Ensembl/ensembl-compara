package GlyphSet::transcript;
use strict;
use vars qw(@ISA);
use lib "..";
use GlyphSet;
@ISA = qw(GlyphSet);
use Glyph::Rect;
use Glyph::Intron;
use Glyph::Text;
use Glyph::Composite;
use lib "../perl";
use Bump;

sub _init {
    my ($this, $VirtualContig, $Config) = @_;

    my $y          = 0;
    my $h          = 8;
    my $highlights = $this->highlights();

    GENE: for my $vg ($VirtualContig->get_all_VirtualGenes()) {
	my $vgid = $vg->gene->id();

	TRANSCRIPT: for my $transcript ($vg->gene->each_Transcript()) {

	    #########
	    # test transcript strand
	    #
	    my $tstrand = $transcript->start_exon()->strand();
	    next TRANSCRIPT if($tstrand != $this->strand());

	    my $Composite = new Glyph::Composite({
		'id'    => $transcript->id(),
		'zmenu' => {
		    'caption'  => $transcript->id(),
		    '01:kung'     => 'opt1',
		    '02:foo'      => 'opt2',
		    '03:fighting' => 'opt3'
		},
	    });

	    #########
	    # set colour for transcripts and test if we're highlighted or not
	    # 
	    my $colour = $Config->get('transview','transcript','col');
	    $colour    = $Config->get('transview','transcript','hi') if(defined $highlights && $highlights =~ /\|$vgid\|/);

	    my $previous_endx = undef;

	    EXON: for my $exon ($transcript->each_Exon()) {
		my $x = $exon->start();
		my $w = $exon->end - $x;

		my $rect = new Glyph::Rect({
		    'x'        => $x,
		    'y'        => $y,
		    'width'    => $w,
		    'height'   => $h,
		    'id'       => $exon->id(),
		    'colour'   => $colour,
		    'zmenu' => {
			'caption' => $exon->id(),
		    },
		});

		my $intron = new Glyph::Intron({
		    'x'        => $previous_endx,
		    'y'        => $y,
		    'width'    => ($x - $previous_endx),
		    'height'   => $h,
		    'id'       => $exon->id(),
		    'colour'   => $colour,
		    'zmenu' => {
			'caption' => 'intron after' . $exon->id(),
		    },
		}) if(defined $previous_endx);

		$Composite->push($rect) if(defined $rect);
		$Composite->push($intron) if(defined $intron);

		$previous_endx = $x+$w;
	    }
	    #########
	    # replace this with bumping!
	    #
	    push @{$this->{'glyphs'}}, $Composite;
	    $y+=$h;
	}
    }
}

1;
