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
			#print STDERR $vg, " ++\n";
	}
	if ($type eq 'all'){
	
    	foreach my $vg ($VirtualContig->get_all_ExternalGenes()){
			$vg->{'_is_external'} = 1;
			push (@allgenes, $vg);
			#print STDERR $vg, " --\n";
		}
    	#push (@allgenes, $VirtualContig->get_all_ExternalGenes());
		
	}
	my $rect;
	my $colour;
    foreach my $vg (@allgenes) {
		my $vgid = $vg->id();
    	foreach my $trans ($vg->each_Transcript()) {

			my $start = $trans->start_exon()->start();
			my $end = $trans->end_exon()->end();
			my $strand = $trans->start_exon()->strand();
			my $id = $vg->id();
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
