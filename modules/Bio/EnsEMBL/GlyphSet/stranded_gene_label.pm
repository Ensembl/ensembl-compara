#########
# stranded_gene_label replacement for gene_label for image dumping
#
# Author: rmp@sanger.ac.uk
#
#
package Bio::EnsEMBL::GlyphSet::stranded_gene_label;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bump;

@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => 'Genes',
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my $self = shift;

    my $VirtualContig  = $self->{'container'};
    my $Config         = $self->{'config'};
    my $y              = 0;
    my @bitmap         = undef;
    my $im_width       = $Config->image_width();
    my $type           = $Config->get($Config->script(),'gene','src');
    my @allgenes       = $VirtualContig->get_all_Genes_exononly();
    my %highlights;
    @highlights{$self->highlights()} = ();    # build hashkeys of highlight list

    if ($type eq 'all'){
	foreach my $vg ($VirtualContig->get_all_ExternalGenes()){
	    $vg->{'_is_external'} = 1;
	    push (@allgenes, $vg);
	}
    }

    my $ext_col        = $Config->get($Config->script(),'gene','ext');
    my $known_col      = $Config->get($Config->script(),'gene','known');
    my $unknown_col    = $Config->get($Config->script(),'gene','unknown');
    my $pix_per_bp     = $Config->transform->{'scalex'};
    my $bitmap_length  = int($VirtualContig->length * $pix_per_bp);
    my $fontname       = "Tiny";
    my ($font_w_bp,$h) = $Config->texthelper->px2bp($fontname);
    my $w              = $Config->texthelper->width($fontname);
    
    for my $vg (@allgenes) {
	
	my ($start, $end, $colour, $label, $hi_colour);
	
	my @coords = ();
	for my $trans ($vg->each_Transcript()) {
	    for my $exon ( $trans->each_Exon_in_context($VirtualContig->id()) ) {
		push @coords, $exon->start();
		push @coords, $exon->end();
	    }
	}
	@coords = sort {$a <=> $b} @coords;
	$start = $coords[0];
	$end   = $coords[-1];   

	unless(defined $vg->{'_is_external'}) {

	    #########
	    # skip if this one isn't on the strand we're drawing
	    #
	    next if(($vg->each_Transcript())[0]->strand_in_context($VirtualContig->id()) != $self->strand());

	    if($vg->is_known()) {
		$colour = $known_col;
		my @temp_geneDBlinks = $vg->each_DBLink();
		my $displaylink;
	 	
		foreach my $DB_link ( @temp_geneDBlinks ){
		    #########################
		    # check for highlighting
		    #########################
		    if (exists $highlights{$DB_link->display_id}){
			$hi_colour = $Config->get($Config->script(), 'gene', 'hi');
		    }

		    if ( $DB_link->database() eq 'HUGO' ) {
			$displaylink = $DB_link;
			last;
		    }

		    if ( 
			$DB_link->database() eq  'SP' ||
			$DB_link->database() eq  'SPTREMBL' ||
			$DB_link->database() eq  'SCOP' ) {
			$displaylink = $DB_link;
		    }
		}

		if (exists $highlights{$vg->id}){
		    $hi_colour = $Config->get($Config->script(), 'gene', 'hi');
		}

		if( $displaylink ) {
		    $label = $displaylink->display_id();
		} else {
		    $label = $vg->id();
		}
		
	    } else {
		$colour = $unknown_col;
		$label	= "NOVEL";
	    }
	} else {
	    #########
	    # skip if it's not on the strand we're drawing
	    #
	    next if(($vg->each_Transcript())[0]->strand_in_context($VirtualContig->id()) != $self->strand());

	    $colour = $ext_col;
	    $label  = $vg->id;
	    $label  =~ s/gene\.//;
	}


	my $Composite = new Bio::EnsEMBL::Glyph::Composite({});
	
	######################
	# Make and bump label
	######################
	$label = " $label";
	my $bp_textwidth = $w * length("$label ");
	my $tglyph = new Bio::EnsEMBL::Glyph::Text({
	    'x'	        => $start,
	    'y'	        => $y,
	    'height'    => $Config->texthelper->height($fontname),
	    'width'     => $font_w_bp * length("$label "),
	    'font'	=> $fontname,
	    'colour'    => $colour,
	    'text'	=> $label,
	    'absolutey' => 1,
	});

	$Composite->push($tglyph);


	#########
	# bump it baby, yeah!
    	# bump-nology!
	#
#    	my $bump_start = int($start * $pix_per_bp);
#	$bump_start    = 0 if ($bump_start < 0);

#    	my $bump_end = $bump_start + $bp_textwidth;
#    	next if $bump_end > $bitmap_length;
#    	my $row = &Bump::bump_row(      
#	    $bump_start,
#	    $bump_end,
#	    $bitmap_length,
#	    \@bitmap
#    	);

	$Composite->colour($hi_colour) if(defined $hi_colour);

	##################################################
	# Draw little taggy bit to indicate start of gene
	##################################################
	my $taggy;

	if($self->strand() == -1) {
	    $taggy = new Bio::EnsEMBL::Glyph::Rect({
		'x'            => $start,
		'y'	       => $tglyph->y() - 1,
		'width'        => 1,
		'height'       => 4,
		'bordercolour' => $colour,
		'absolutey'    => 1,
	    });
	} elsif($self->strand() == 1) {
	    $taggy = new Bio::EnsEMBL::Glyph::Rect({
		'x'	       => $start,
		'y'	       => $tglyph->y() - 1 + 4,
		'width'        => 1,
		'height'       => 4,
		'bordercolour' => $colour,
		'absolutey'    => 1,
	    });
	}
	
	$Composite->push($taggy);
	$taggy = new Bio::EnsEMBL::Glyph::Rect({
	    'x'	           => $start,
	    'y'	           => $tglyph->y - 1 + 4,
	    'width'        => $font_w_bp * 0.5,
	    'height'       => 0,
	    'bordercolour' => $colour,
	    'absolutey'    => 1,
	});
	
    	$Composite->push($taggy);


	#########
	# bump it baby, yeah!
	#
        my $bump_start = int($Composite->x * $pix_per_bp);
        $bump_start = 0 if ($bump_start < 0);

        my $bump_end = $bump_start + int($Composite->width * $pix_per_bp);
        if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};

        my $row = &Bump::bump_row(
            $bump_start,
            $bump_end,
            $bitmap_length,
            \@bitmap
        );

        #########
        # shift the composite container by however much we're bumped
        #
        $Composite->y($Composite->y() + (1.5 * $row * $h * -$self->strand()));
        $self->push($Composite);
    }
}

1;
