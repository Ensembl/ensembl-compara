package Bio::EnsEMBL::GlyphSet::gene;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bump;

sub _init {
    my ($this, $VirtualContig, $Config) = @_;

    return unless ($this->strand() == -1);

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'genes',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);

    my $y             = 0;
    my $h             = 8;
    my $highlights    = $this->highlights();
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $bitmap_length = $VirtualContig->length();
    my $type          = $Config->get($Config->script(),'gene','src');
    my @allgenes      = ();

    push @allgenes, $VirtualContig->get_all_VirtualGenes_startend();

    if ($type eq 'all'){
	foreach my $vg ($VirtualContig->get_all_ExternalGenes()){
	    $vg->{'_is_external'} = 1;
	    push (@allgenes, $vg);
	}
    }

    my $ext_col     = $Config->get($Config->script(),'gene','ext');
    my $known_col   = $Config->get($Config->script(),'gene','known');
    my $unknown_col = $Config->get($Config->script(),'gene','unknown');

    foreach my $vg (@allgenes) {

	my $vgid  = $vg->id();
	my ($start, $end, $colour);

	if($vg->isa("Bio::EnsEMBL::VirtualGene")) {
	    $colour   = $vg->gene->is_known()?$known_col:$unknown_col;
	    $start    = $vg->start();
	    $end      = $vg->end();
	} else {
	    $colour   = $ext_col;
	    $start    = ($vg->each_Transcript())[0]->start_exon->start();
	    $end      = ($vg->each_Transcript())[-1]->end_exon->end();
	}

	my $rect = new Bio::EnsEMBL::Glyph::Rect({
	    'x'         => $start,
	    'y'         => $y,
	    'width'     => $end - $start,
	    'height'    => $h,
	    'colour'    => $colour,
	    'absolutey' => 1,
	    'zmenu'     => {
		'caption' => $vgid,
	    },
	});

	#########
	# bump it baby, yeah!
    	# bump-nology!
	#
    	my $bump_start = $rect->x();
		$bump_start    = 0 if ($bump_start < 0);

    	my $bump_end = $bump_start + ($rect->width());
    	next if $bump_end > $bitmap_length;
    	my $row = &Bump::bump_row(      
	    $bump_start,
	    $bump_end,
	    $bitmap_length,
	    \@bitmap
    	);

	    next if $row > $Config->get($Config->script(), 'gene', 'dep');
    	$rect->y($rect->y() + (1.5 * $row * $h));
    	$this->push($rect);
    }
}

1;
