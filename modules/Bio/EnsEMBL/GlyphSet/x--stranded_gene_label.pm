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
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Composite;
use  Sanger::Graphics::Bump;

@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Sanger::Graphics::Glyph::Text({
        'text'      => 'Genes',
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my $self = shift;

    my $vc             = $self->{'container'};
    my $Config         = $self->{'config'};
    my $y              = 0;
    my @bitmap         = undef;
    my $im_width       = $Config->image_width();
    my $type           = $Config->get('stranded_gene_label','src');
    my @allgenes       = $vc->get_all_VirtualGenes_startend();
    my %highlights;
    @highlights{$self->highlights()} = ();    # build hashkeys of highlight list

    if ($type eq 'all') {
    	foreach my $vg ($vc->get_all_ExternalGenes()){
    	    $vg->{'_is_external'} = 1;
    	    push (@allgenes, $vg);
    	}
    }

    my $ext_col        = $Config->get('stranded_gene_label','ext');
    my $pseudo_col     = $Config->get('stranded_gene_label','pseudo');
    my $known_col      = $Config->get('stranded_gene_label','known');
    my $unknown_col    = $Config->get('stranded_gene_label','unknown');
    my $hi_colour      = $Config->get('stranded_gene_label','hi');
    my $pix_per_bp     = $Config->transform->{'scalex'};
    my $bitmap_length  = int($vc->length * $pix_per_bp);
    my $fontname       = "Tiny";
    my ($font_w_bp,$h) = $Config->texthelper->px2bp($fontname);
    my $w              = $Config->texthelper->width($fontname);
    my %db_names = (
        'HUGO'          => 100,
        'SP'            =>  90,
        'SWISS-PROT'    =>  80,
        'SPTREMBL'      =>  70,
        'SCOP'          =>  60,
        'LocusLink'     =>  50,
        'RefSeq'        =>  40 
    );

    for my $vg (@allgenes) {
	
	my ($start, $genetype, $highlight, $colour, $label);
	
    if($vg->isa("Bio::EnsEMBL::VirtualGene")) {
        ($genetype, $label, $highlight, $start) = $self->virtualGene_details( $vg, %highlights );
        $colour = $genetype eq 'known' ? $known_col : $unknown_col;
    } else { # EXTERNAL ANNOYING GENES
        ($genetype, $label, $highlight, $start) = $self->externalGene_details( $vg, $vc->id, %highlights );
        $colour   = $genetype eq 'pseudo' ? $pseudo_col : $ext_col;
    }

	my $Composite = new Sanger::Graphics::Glyph::Composite({});
	
	######################
	# Make and bump label
	######################
	my $tglyph = new Sanger::Graphics::Glyph::Text({
	    'x'	        => $start + $font_w_bp,
	    'y'	        => $y,
	    'height'    => $Config->texthelper->height($fontname),
	    'width'     => $font_w_bp * length($label),
	    'font'	=> $fontname,
	    'colour'    => $colour,
	    'text'	=> $label,
	    'absolutey' => 1,
	});

	$Composite->push($tglyph);
	$Composite->colour($hi_colour) if($highlight);

	##################################################
	# Draw little taggy bit to indicate start of gene
	##################################################
	my $taggy;

	if($self->strand() == -1) {
	    $taggy = new Sanger::Graphics::Glyph::Rect({
		'x'            => $start,
		'y'	       => $tglyph->y(),
		'width'        => 1,
		'height'       => 4,
		'bordercolour' => $colour,
		'absolutey'    => 1,
	    });
	} elsif($self->strand() == 1) {
	    $taggy = new Sanger::Graphics::Glyph::Rect({
		'x'	       => $start,
		'y'	       => $tglyph->y() + 3,
		'width'        => 1,
		'height'       => 4,
		'bordercolour' => $colour,
		'absolutey'    => 1,
	    });
	}
	
	$Composite->push($taggy);
	$taggy = new Sanger::Graphics::Glyph::Rect({
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

        my $row = & Sanger::Graphics::Bump::bump_row(
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
