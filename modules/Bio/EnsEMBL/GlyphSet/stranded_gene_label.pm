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
    my ($self) = @_;
	return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Bio::EnsEMBL::Glyph::Text({
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
	
	my ($start, $colour, $label, $hi_colour);
	
	if($vg->isa("Bio::EnsEMBL::VirtualGene")) {
	    ########## skip if this one isn't on the strand we're drawing
        next if( $vg->strand() != $self->strand() );
        $start = $vg->start();
	    if($vg->gene->is_known()) {
                # this is duplicated  from gene_label.pm, so needs refactoring ...
	    	$colour = $known_col;
            my @temp_geneDBlinks = $vg->gene->each_DBLink();
	 	
                # find a decent label:
            my $max_pref = 0;
            $label = $vg->id();
    		foreach my $DB_link ( @temp_geneDBlinks ) {
                my $db = $DB_link->database();
                # reset if precedence is higher!
                if( $db_names{$db} && $db_names{$db}>$max_pref) {
                    $label = $DB_link->display_id();
                    $max_pref = $db_names{$db};
                }
    		}
            # check for highlighting
	    	if (exists $highlights{$label}){
    		    $hi_colour = $Config->get( 'stranded_gene_label', 'hi');
    		}
        } else {
	    	$colour = $unknown_col;
    		$label	= "NOVEL";
	    }
	} else {
        next if(($vg->each_Transcript())[0]->strand_in_context($vc->id()) != $self->strand());    
	    ########## skip if it's not on the strand we're drawing
		$colour   =  ($vg->type() =~ /pseudo/) ? $pseudo_col : $ext_col;
        $start = undef;
	    foreach my $trans ($vg->each_Transcript){
    		foreach my $exon ( $trans->each_Exon ) {
#                print STDERR "XX: ".join(' -- ',$exon->seqname(),$vc->id(),$exon->start,$start,"\n");
    		    if( ($exon->seqname eq $vc->id) && ( $exon->start < $start || !defined $start) ) { 
        			$start = $exon->start;
		        }
	        }
	    }
	    $label  = $vg->id;
	    $label  =~ s/gene\.//;
	}

	my $Composite = new Bio::EnsEMBL::Glyph::Composite({});
	
	######################
	# Make and bump label
	######################
	my $tglyph = new Bio::EnsEMBL::Glyph::Text({
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
	$Composite->colour($hi_colour) if(defined $hi_colour);

	##################################################
	# Draw little taggy bit to indicate start of gene
	##################################################
	my $taggy;

	if($self->strand() == -1) {
	    $taggy = new Bio::EnsEMBL::Glyph::Rect({
		'x'            => $start,
		'y'	       => $tglyph->y(),
		'width'        => 1,
		'height'       => 4,
		'bordercolour' => $colour,
		'absolutey'    => 1,
	    });
	} elsif($self->strand() == 1) {
	    $taggy = new Bio::EnsEMBL::Glyph::Rect({
		'x'	       => $start,
		'y'	       => $tglyph->y() + 3,
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
