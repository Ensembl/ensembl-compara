package Bio::EnsEMBL::GlyphSet::gene_label_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);

@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
    my $self = shift;

##############################################################################
# Unstranded (on reverse strand!)                                            #
##############################################################################
# May want to change this so that it works on the forward strand, and also   #
# as a stranded version as well!!!                                           #
##############################################################################
    return unless ($self->strand() == -1);

##############################################################################
# Stage 1: Parse parameters                                                  #
##############################################################################

##############################################################################
# Stage 1a: Firstly the configuration hash!                                  #
##############################################################################
    my $Config         = $self->{'config'};
    my $known_col      = $Config->get( 'gene_label_lite' , 'known' );
    my $hi_col         = $Config->get( 'gene_label_lite' , 'hi' );
    my $unknown_col    = $Config->get( 'gene_label_lite' , 'unknown' );
    my $ext_col        = $Config->get( 'gene_label_lite' , 'ext' );
    my $pseudo_col     = $Config->get( 'gene_label_lite' , 'pseudo' );
    my $max_length     = $Config->get( 'gene_label_lite' , 'threshold' ) || 2000000;
    my $navigation     = $Config->get( 'gene_label_lite' , 'navigation' ) || 'off';
    my $max_length_nav = $Config->get( 'gene_label_lite' , 'navigation_threshold' ) || 200000;
    my $im_width       = $Config->image_width();
    my $type           = $Config->get( 'gene_label_lite' , 'src' );
    my $pix_per_bp     = $Config->transform->{'scalex'};
    my $fontname       = "Tiny";
    my ($font_w_bp,$h) = $Config->texthelper->px2bp($fontname);
    my $w              = $Config->texthelper->width($fontname);

##############################################################################
# Stage 1b: Now the virtual contig                                           #
##############################################################################
    my $vc              = $self->{'container'};
    my $vc_length       = $vc->length;
    if( $vc_length > ($max_length*1001)) {
        $self->errorTrack("Gene labels only displayed for less than $max_length Kb.");
        return;
    }
	my $show_navigation = $navigation eq 'on' && ( $vc->length() < $max_length_nav * 1001 );
    my $bitmap_length   = int($vc_length * $pix_per_bp);
	my $vc_start        = $vc->_global_start();

##############################################################################
# Stage 1c: Initialize other arrays/numbers                                  #
##############################################################################
    my $y             = 0;
    my %highlights;
    @highlights{$self->highlights} = (); # build hashkeys of highlight list
    my @bitmap        = undef;
    my @allgenes      = ();
    my @genes = ();

##############################################################################
# Stage 2: Retrieve the gene information from the databases                  #
##############################################################################

##############################################################################
# Stage 2a: Retrieve all EnsEMBL genes                                       #
##############################################################################
    &eprof_start("gene-virtualgene_start-get");
    my $res = $vc->get_all_VirtualGenes_startend_lite();
    foreach(@$res) {
        my( $gene_col, $gene_label, $high);
        $high = exists $highlights{$_->{'stable_id'}} ? 1 : 0;
        if(defined $_->{'synonym'}) {
            $gene_col = $known_col;
            $gene_label = $_->{'synonym'};
            $high = 1 if(exists $highlights{$gene_label});
        } else {
            $gene_col = $unknown_col;
            $gene_label = 'NOVEL'; 
        }
        push @genes, {
            'chr_start' => $_->{'chr_start'},
            'chr_end'   => $_->{'chr_end'},
            'start'     => $_->{'start'},
            'strand'    => $_->{'strand'},
            'end'       => $_->{'end'},
            'ens_ID'    => $_->{'stable_id'},
            'label'     => $gene_label,
            'colour'    => $gene_col,
            'ext_DB'    => $_->{'db'},
            'high'      => $high
        };
    }
    &eprof_end("gene-virtualgene_start-get");

##############################################################################
# Stage 2b: Retrieve all EMBL (external) genes                               #
##############################################################################
    &eprof_start("gene-externalgene_start-get");
    if ($type eq 'all'){
        my $res = $vc->get_all_EMBLGenes_startend_lite();
        foreach my $g (@$res){
            my( $gene_col, $gene_label, $high);
            $high       = exists $highlights{ $g->{'stable_id'} } ? 1 : 0;
            $gene_label = $g->{'synonym'};
            $high       = 1 if(exists $highlights{ $gene_label });
            if(defined $_->{'type'} eq 'pseudo') {
                $gene_col = $pseudo_col;
            } else {
                $gene_col = $ext_col;
            }
            push @genes, {
                'chr_start' => $g->{'chr_start'},
                'chr_end'   => $g->{'chr_end'},
                'start'     => $g->{'start'},
                'strand'    => $_->{'strand'},
                'end'       => $g->{'end'},
                'ens_ID'    => '', #$g->{'stable_id'},
                'label'     => $gene_label,
                'colour'    => $gene_col,
                'ext_DB'    => $g->{'db'},
                'high'      => $high,
                'type'      => 'external'
            };
        }
    }
    &eprof_end("gene-externalgene_start-get");

##############################################################################
# Stage 3: Render gene labels                                                #
##############################################################################
    my @gene_glyphs = ();
    foreach my $g (@genes) {
		my $start = $g->{'start'};
        my $end   = $g->{'end'};
		next if(  $end < 1 || $start > $vc_length );
		
        $start = 1 if $start<1;
        $end = $vc_length if $end > $vc_length;
        my $label = $g->{'label'};

        my $tglyph = new Bio::EnsEMBL::Glyph::Text({
            'x'         => $start,	
            'y'         => $y,
            'height'    => $Config->texthelper->height($fontname),
            'width'     => $font_w_bp * length(" $label "),
            'font'      => $fontname,
            'colour'    => $g->{'colour'},
            'text'      => " $label",
            'absolutey' => 1,
        });
		if($show_navigation) {
			$tglyph->{'zmenu'} = {
				'caption' 											=> $label,
				"bp: $g->{'chr_start'}-$g->{'chr_end'}" 			=> '',
				"length: ".($g->{'chr_end'}-$g->{'chr_start'}+1) 	=> ''
			}; 
			$tglyph->{'zmenu'}->{"Gene: $g->{'ens_ID'}"} = "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$g->{'ens_ID'}" if $g->{'ens_ID'} ne '';
		}
		
        my $depth = $Config->get('gene_label_lite', 'dep');
        if ($depth > 0){ # we bump
            my $bump_start = int($tglyph->x() * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);
    
            my $bump_end = $bump_start + int($tglyph->width()*$pix_per_bp) +1;
            $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
            my $row = &Bump::bump_row(
                $bump_start,
                        $bump_end,
                        $bitmap_length,
                        \@bitmap
            );
    
            #next if $row > $depth;
                $tglyph->y($tglyph->y() + (1.2 * $row * $h) + 1);
        }
		
        push @gene_glyphs, $tglyph;
        ##################################################
        # Draw little taggy bit to indicate start of gene
        ##################################################
        my $taggy = new Bio::EnsEMBL::Glyph::Rect({
            'x'            => $start,
            'y'            => $tglyph->y - 1,
            'width'        => 1,
            'height'       => 4,
            'bordercolour' => $g->{'colour'},
            'absolutey'    => 1,
        });
    
        push @gene_glyphs, $taggy;
        $taggy = new Bio::EnsEMBL::Glyph::Rect({
            'x'            => $start,
            'y'            => $tglyph->y - 1 + 4,
            'width'        => $font_w_bp * 0.5,
            'height'       => 0,
            'bordercolour' => $g->{'colour'},
            'absolutey'    => 1,
        });
    
        push @gene_glyphs, $taggy;
        ##################################################
        # Highlight label if required.....
        ##################################################
        if($g->{'high'}) {
            my $rect2 = new Bio::EnsEMBL::Glyph::Rect({
                'x'         => $tglyph->x() + $font_w_bp,
                'y'         => $tglyph->y(),
                'width'     => $font_w_bp * length($label),
                'height'    => $tglyph->height(),
                'colour'    => $hi_col,
                'absolutey' => 1,
            });
            $self->push($rect2);
        }
    }

##############################################################################
# Stage 3b: Push genes on to track                                           #
##############################################################################
    foreach( @gene_glyphs) {
        $self->push($_);
    }
}

1;
