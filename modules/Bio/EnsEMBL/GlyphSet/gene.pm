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
    my $im_width    = $Config->image_width();
    my $bitmap_length = $VirtualContig->length();
    my $type = $Config->get($Config->script(),'gene','src');
    my @allgenes = ();

    foreach my $vg ($VirtualContig->get_all_VirtualGenes()){
	push (@allgenes, $vg->gene());
    }

    if ($type eq 'all'){

	foreach my $vg ($VirtualContig->get_all_ExternalGenes()){
	    $vg->{'_is_external'} = 1;
	    push (@allgenes, $vg);
	}
    }

    my $rect;
    my $colour;
    foreach my $vg (@allgenes) {
	my $vgid = $vg->id();
    	foreach my $transcript ($vg->each_Transcript()) {

	    my $strand = $transcript->strand_in_context($VirtualContig->id());

            my @exons    = $transcript->each_Exon_in_context($VirtualContig->id());
	    my $last_idx = scalar @exons - 1;

            my ($start_screwed, $end_screwed, $start, $end);

            if($strand == 1) {
                $start_screwed = $transcript->is_start_exon_in_context($VirtualContig->id());
                $end_screwed   = $transcript->is_end_exon_in_context($VirtualContig->id());

		if(defined $start_screwed && $start_screwed == 0) {
		    $start = 0;
		} else {
		    $start = $exons[0]->start();
		}

		if(defined $end_screwed && $end_screwed == 0) {
		    $end = $VirtualContig->length();
		} else {
		    $end = $exons[$last_idx]->end();
		}
            } else {
		#########
		# same as above, but @exons is reversed for reverse strand
		#
                $end_screwed   = $transcript->is_start_exon_in_context($VirtualContig->id());
                $start_screwed = $transcript->is_end_exon_in_context($VirtualContig->id());

		if(defined $start_screwed && $start_screwed == 0) {
		    $start = 0;
		} else {
		    $start = $exons[$last_idx]->start();
		}

		if($end_screwed && $end_screwed == 0) {
		    $end = $VirtualContig->length();
		} else {
		    $end = $exons[0]->end();
		}

            }

	    my $id     = $vg->id();

	    if ($vg->is_known()){
    		$colour = $Config->get($Config->script(),'gene','known');
	    } else {
    		$colour = $Config->get($Config->script(),'gene','unknown');
	    }

            if ($vg->{'_is_external'}){
		$colour = $Config->get($Config->script(),'gene','ext');
	    }

	    $rect = new Bio::EnsEMBL::Glyph::Rect({
		'x'        => $start,
		'y'        => $y,
		'width'    => $end - $start,
		'height'   => $h,
		'colour'   => $colour,
		'absolutey' => 1,
		'zmenu' => {
		    'caption' => $vgid,
		},
	    });
    	}

	#########
	# bump it baby, yeah!
    	# bump-nology!
	#
    	my $bump_start = $rect->x();
	$bump_start = 0 if ($bump_start < 0);

    	my $bump_end = $bump_start + ($rect->width());
    	next if $bump_end > $bitmap_length;
    	my $row = &Bump::bump_row(      
	    $bump_start,
	    $bump_end,
	    $bitmap_length,
	    \@bitmap
    	);

    	$rect->y($rect->y() + (1.5 * $row * $h));
    	$this->push($rect);
    }
}

1;
