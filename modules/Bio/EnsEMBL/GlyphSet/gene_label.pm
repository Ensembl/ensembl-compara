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
    my $Config        = $self->{'config'};
    my $y             = 0;
    my %highlights;
    @highlights{$self->highlights} = ();    # build hashkeys of highlight list
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $type          = $Config->get('gene_label', 'src');
    my @allgenes      = ();

    
    push @allgenes, $VirtualContig->get_all_VirtualGenes_startend();

    if ($type eq 'all'){
	foreach my $vg ($VirtualContig->get_all_ExternalGenes()){
	    $vg->{'_is_external'} = 1;
	    push (@allgenes, $vg);
	}
    }

    my $ext_col        = $Config->get('gene_label','ext');
    my $known_col      = $Config->get('gene_label','known');
    my $unknown_col    = $Config->get('gene_label','unknown');
    my $pseudo_col     = $Config->get('gene_label','pseudo');
    my $pix_per_bp     = $Config->transform->{'scalex'};
    my $bitmap_length  = int($VirtualContig->length * $pix_per_bp);
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
    foreach my $vg (@allgenes) {

	my ($start, $end, $colour, $label,$hi_colour);
	
	if($vg->isa("Bio::EnsEMBL::VirtualGene")) {
	    $start  = $vg->start();
	    $end    = $vg->end();

	    if ($vg->gene->is_known) {
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
    		    $hi_colour = $Config->get( 'gene_label', 'hi');
    		}
	    } else {
    		$colour = $unknown_col;
    		$label	= "NOVEL";
	    }
	} else {
	    # EXTERNAL ANNOYING GENES
	    $colour   = $ext_col;
		if ($vg->type() =~ /pseudo/){
	    	$colour   = $pseudo_col;
		}
	    my @coords;
	    foreach my $trans ($vg->each_Transcript){
    		foreach my $exon ( $trans->each_Exon ) {
    		    if( $exon->seqname eq $VirtualContig->id ) { 
        			push(@coords,$exon->start);
           			push(@coords,$exon->end);
		        }
	        }
	    }
	    @coords = sort {$a <=> $b} @coords;
	    $start = $coords[0];
	    $end   = $coords[-1];   
	    $label  = $vg->id;
	    $label  =~ s/gene\.//;
	}                               # isa VirtualGene
	
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

	if(defined $hi_colour) {
	    my $hilite = new Bio::EnsEMBL::Glyph::Rect({
		'x'         => $tglyph->x() + ($font_w_bp+1 * 0.5),
		'y'         => $tglyph->y(),
		'width'     => $tglyph->width(),
		'height'    => $tglyph->height(),
		'colour'    => $hi_colour,
		'bordercolour' => $hi_colour,
		'absolutey' => 1,
	    });
	    $self->push($hilite);
	}

    	$self->push($tglyph);
	
	##################################################
	# Draw little taggy bit to indicate start of gene
	##################################################
	my $taggy = new Bio::EnsEMBL::Glyph::Rect({
	    'x'	           => $start,
	    'y'	           => $tglyph->y - 1,
	    'width'        => 1,
	    'height'       => 4,
	    'bordercolour' => $colour,
	    'absolutey'    => 1,
	});
	
    	$self->push($taggy);
	$taggy = new Bio::EnsEMBL::Glyph::Rect({
	    'x'	           => $start,
	    'y'	           => $tglyph->y - 1 + 4,
	    'width'        => $font_w_bp * 0.5,
	    'height'       => 0,
	    'bordercolour' => $colour,
	    'absolutey'    => 1,
	});
	
    	$self->push($taggy);
    }
}

1;
