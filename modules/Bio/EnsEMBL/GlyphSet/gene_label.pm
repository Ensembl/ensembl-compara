package Bio::EnsEMBL::GlyphSet::gene_label;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bump;

@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my $self = shift;

    return unless ($self->strand() == -1);

    my $VirtualContig = $self->{'container'};
    my $Config = $self->{'config'};

    my $y             = 0;
    my $highlights    = $self->highlights();
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $type          = $Config->get($Config->script(),'gene','src');
    my @allgenes      = ();

    push @allgenes, $VirtualContig->get_all_VirtualGenes_startend();

    #if ($type eq 'all'){
	#foreach my $vg ($VirtualContig->get_all_ExternalGenes()){
	#    $vg->{'_is_external'} = 1;
	#    push (@allgenes, $vg);
	#}
    #}

    my $ext_col     = $Config->get($Config->script(),'gene','ext');
    my $known_col   = $Config->get($Config->script(),'gene','known');
    my $unknown_col = $Config->get($Config->script(),'gene','unknown');
    my $pix_per_bp  = $Config->transform->{'scalex'};
    my $bitmap_length = int($VirtualContig->length * $pix_per_bp);
    my $fontname = "Tiny";
    my ($font_w_bp,$h) = $Config->texthelper->px2bp($fontname);
    my $w = $Config->texthelper->width($fontname);

    foreach my $vg (@allgenes) {

	my ($start, $end, $colour, $label);

	if($vg->isa("Bio::EnsEMBL::VirtualGene")) {
	    $start  = $vg->start();
	    $end    = $vg->end();
	    if ($vg->gene->is_known){
		$colour = $known_col;
		my @temp_geneDBlinks = $vg->gene->each_DBLink;
		my ($hugo, $swisslink, $sptrembllink);
		
		foreach my $DB_link ( @temp_geneDBlinks ){
		    if( $DB_link->database eq 'HUGO' ) {
			$hugo = $DB_link;
			last;
		    }
		    if( $DB_link->database =~ /SWISS/o ) {
			$swisslink = $DB_link;
		    }
		    if( $DB_link->database eq 'SPTREMBL' ) {
			$sptrembllink = $DB_link;
		    }
		}

		if( $hugo ) {
		    $label = $hugo->primary_id;
		} 
		elsif ( $swisslink ) {
		    $label = $swisslink->primary_id;
		} 
		elsif ( $sptrembllink ) {
		    $label = $sptrembllink->primary_id;
		} 
		else {
		    $label = $vg->id;
		}
	    }
	    else {
		$colour = $unknown_col;
		$label	= "UNKNOWN";
	    }
	} else {
	    # ignore pesky external genes for the moment
	    next;
	    $colour = $ext_col;
	    $start  = ($vg->each_Transcript())[0]->start_exon->start();
	    $end    = ($vg->each_Transcript())[-1]->end_exon->end();
	    $label  = $vg->id;
	    $label  =~ s/gene\.//;
	
	}
	
	######################
	# Make and bump label
	######################
	$label = " $label";
	my $tglyph = new Bio::EnsEMBL::Glyph::Text({
		'x'	    => $start,
		'y'	    => $y,
		'height'    => $Config->texthelper->height($fontname),
		'font'	    => $fontname,
		'colour'    => $colour,
		'text'	    => $label,
		'absolutey' => 1,
		});

	my $bp_textwidth = $w * length("$label ");

	#########
	# bump it baby, yeah!
    	# bump-nology!
	#
    	my $bump_start = int($start * $pix_per_bp);
	$bump_start    = 0 if ($bump_start < 0);

    	my $bump_end = $bump_start + $bp_textwidth;
    	next if $bump_end > $bitmap_length;
    	my $row = &Bump::bump_row(      
	    $bump_start,
	    $bump_end,
	    $bitmap_length,
	    \@bitmap
    	);

    	$tglyph->y($tglyph->y() + (1.2 * $row * $h) + 1);
    	$self->push($tglyph);
	
	##################################################
	# Draw little taggy bit to indicate start of gene
	##################################################
	my $taggy = new Bio::EnsEMBL::Glyph::Rect({
		'x'	    => $start,
		'y'	    => $tglyph->y - 1,
		'width'     => 1,
		'height'    => 4,
		'bordercolour'    => $colour,
		'absolutey' => 1,
		});
	
    	$self->push($taggy);
	$taggy = new Bio::EnsEMBL::Glyph::Rect({
		'x'	    => $start,
		'y'	    => $tglyph->y - 1 + 4,
		'width'     => $font_w_bp * 0.5,
		'height'    => 0,
		'bordercolour'    => $colour,
		'absolutey' => 1,
		});
	
    	$self->push($taggy);
    }
}

1;
