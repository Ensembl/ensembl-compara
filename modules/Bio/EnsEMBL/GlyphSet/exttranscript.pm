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
    my @bitmap      = undef;
    my ($im_width, $im_height) = $Config->dimensions();
    my $bitmap_length = $VirtualContig->length();


	my @vg = $VirtualContig->get_all_ExternalGenes();
	my $colour = $Config->get($Config->script(),'extgene','col');
    foreach my $vg (@vg) {
	my $vgid = $vg->id();

	foreach my $transcript ($vg->each_Transcript()) {
	    my $tstrand = $transcript->start_exon()->strand();
	    next if($tstrand != $this->strand());
        my $hi_colour;
		$hi_colour = $Config->get($Config->script(),'extgene','hi') if(defined $highlights && $highlights =~ /\|$vgid\|/);
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
	    @exons = reverse @exons if($tstrand == -1);
	    foreach my $exon (@exons) {
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
        #bump-nology!
        ###################################################
        my $bump_start = $Composite->x();
        if ($bump_start < 0){$bump_start = 0};

        my $bump_end = $bump_start + ($Composite->width());
        next if $bump_end > $bitmap_length;
        my $row = &Bump::bump_row(      
                                $bump_start,
                                $bump_end,
                                $bitmap_length,
                                \@bitmap
        );

        next if $row > $Config->get($Config->script(), 'exttranscript', 'dep');
        ###################################################

        $Composite->y($Composite->y() + (1.5 * $row * $h * -$tstrand));
        $this->push($Composite);
	}
    }
}

1;
