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

    my $vc            = $self->{'container'};
    my $Config        = $self->{'config'};
    my $y             = 0;
    my %highlights;
    @highlights{$self->highlights} = ();    # build hashkeys of highlight list
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $type          = $Config->get('gene_label', 'src');
    my @allgenes      = ();
    
    push @allgenes, $vc->get_all_VirtualGenes_startend();

    #if ($type eq 'all'){
    #    foreach my $vg ($vc->get_all_ExternalGenes()){
    #        $vg->{'_is_external'} = 1;
    #        push (@allgenes, $vg);
    #    }
    #}

    my $ext_col        = $Config->get( 'gene_label' , 'ext' );
    my $known_col      = $Config->get( 'gene_label' , 'known' );
    my $unknown_col    = $Config->get( 'gene_label' , 'unknown' );
    my $pseudo_col     = $Config->get( 'gene_label' , 'pseudo' );
    my $hi_colour      = $Config->get( 'gene_label' , 'hi' );

    my $pix_per_bp     = $Config->transform->{'scalex'};
    my $bitmap_length  = int($vc->length * $pix_per_bp);
    my $fontname       = "Tiny";
    my ($font_w_bp,$h) = $Config->texthelper->px2bp($fontname);
    my $w              = $Config->texthelper->width($fontname);
    foreach my $vg (@allgenes) {
        my ($start, $colour, $label, $genetype);
        my $highlight = 0;
    
        if($vg->isa("Bio::EnsEMBL::VirtualGene")) {
            ($genetype, $label, $highlight, $start) = $self->virtualGene_details( $vg, %highlights );
            $colour = $genetype eq 'known' ? $known_col : $unknown_col;
        } else { # EXTERNAL ANNOYING GENES
            ($genetype, $label, $highlight, $start) = $self->externalGene_details( $vg, $vc->id, %highlights );
            $colour   = $genetype eq 'pseudo' ? $pseudo_col : $ext_col;
        }
    
        ####################### Make and bump label
        $label = " $label";
        my $bp_textwidth = $w * length("$label ");
        my $tglyph = new Bio::EnsEMBL::Glyph::Text({
            'x'         => $start,
            'y'         => $y,
            'height'    => $Config->texthelper->height($fontname),
            'width'     => $font_w_bp * length("$label"),
            'font'      => $fontname,
            'colour'    => $colour,
            'text'      => $label,
            'absolutey' => 1,
        });

        ########## bump it baby, yeah! # bump-nology!
        my $bump_start = int($start * $pix_per_bp);
        $bump_start    = 0 if ($bump_start < 0);
    
        my $bump_end = $bump_start + $bp_textwidth;
        next if $bump_end > $bitmap_length; # Skip label if will fall off RHS
        my $row = &Bump::bump_row(      
            $bump_start,
            $bump_end,
            $bitmap_length,
            \@bitmap
        );

        $tglyph->y($tglyph->y() + (1.2 * $row * $h) + 1);

        if($highlight) {
            my $hilite = new Bio::EnsEMBL::Glyph::Rect({
            'x'             => $tglyph->x() + ($font_w_bp+1 * 0.5),
            'y'             => $tglyph->y(),
            'width'         => $tglyph->width(),
            'height'        => $tglyph->height(),
            'colour'        => $hi_colour,
            'bordercolour'  => $hi_colour,
            'absolutey'     => 1,
            });
            $self->push($hilite);
        }

        $self->push($tglyph);
    
        ##################################################
        # Draw little taggy bit to indicate start of gene
        ##################################################
        my $taggy = new Bio::EnsEMBL::Glyph::Rect({
            'x'               => $start,
            'y'               => $tglyph->y - 1,
            'width'        => 1,
            'height'       => 4,
            'bordercolour' => $colour,
            'absolutey'    => 1,
        });
    
        $self->push($taggy);
        $taggy = new Bio::EnsEMBL::Glyph::Rect({
            'x'               => $start,
            'y'               => $tglyph->y - 1 + 4,
            'width'        => $font_w_bp * 0.5,
            'height'       => 0,
            'bordercolour' => $colour,
            'absolutey'    => 1,
        });
    
        $self->push($taggy);
    }
}

1;
