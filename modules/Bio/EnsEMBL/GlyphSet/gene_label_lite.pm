=head1 NAME

Bio::EnsEMBL::GlyphSet::gene_label_lite -
Glyphset for gene labels in contigviewtop

=head1 USED BY

    Bio::EnsEMBL::GlyphSet::vega_gene_label_lite_havana
    Bio::EnsEMBL::GlyphSet::vega_gene_label_lite_genoscope
    Bio::EnsEMBL::GlyphSet::vega_gene_label_lite_sanger
    Bio::EnsEMBL::GlyphSet::vega_gene_label_lite_zfish

=cut

package Bio::EnsEMBL::GlyphSet::gene_label_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Bump;

sub checkDB {
    my $db = EnsWeb::species_defs->databases   || {};
    return $db->{$_[0]} && $db->{$_[0]}->{NAME};
}

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
    my $authority = EnsWeb::species_defs->AUTHORITY;
    my $Config         = $self->{'config'};
    my $im_width       = $Config->image_width();
    my $type           = $Config->get( 'gene_label_lite' , 'src' );
    my $pix_per_bp     = $Config->transform->{'scalex'};
    my $fontname       = "Tiny";
    my ($font_w_bp,$h) = $Config->texthelper->px2bp($fontname);
    my $w              = $Config->texthelper->width($fontname);
    my $colours = $Config->get('gene_lite','colours');
    my $max_length     = $Config->get('gene_label_lite','threshold') || 1e6;
    my $max_length_nav = $Config->get('gene_label_lite','navigation_threshold') || 50e3;
    my $navigation     = $Config->get('gene_label_lite','navigation') || 'off';

##############################################################################
# Stage 1b: Now the virtual contig                                           #
##############################################################################
    my $vc              = $self->{'container'};
    my $vc_length       = $vc->length;
    if( $vc_length > ($max_length*1001)) {
        $self->errorTrack("Gene labels only displayed for less than $max_length Kb.");
        return;
    }
    my $show_navigation = $navigation eq 'on' && ( $vc_length < $max_length_nav * 1001 );
    my $bitmap_length   = int($vc_length * $pix_per_bp);
	my $vc_start        = $vc->chr_start();
    my $offset = $vc_start-1;
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
# Stage 2a: Retrieve all Vega genes                                        #
##############################################################################

    my %gene_objs;
    foreach my $g (@{$vc->get_all_Genes('', 1)}) {
      my $source = lc($g->analysis->logic_name);
      $gene_objs{$source} ||= [];
      push @{$gene_objs{$source}}, $g;
    }
    
    ## get vega logic names from child
    my $logic_name;
    if ($self->can('logic_name')) {
        $logic_name = $self->logic_name;
    }
    foreach my $g (@{$gene_objs{'otter'}}, @{$gene_objs{$logic_name}}) { 
      my $gene_label = $g->external_name() || $g->stable_id();   
      my $high = exists $highlights{ $gene_label }; 
      my $type = $g->type(); 
      $type =~ s/HUMACE-//; 
      my $gene_col = $colours->{ "$type" }; 
        push @genes, { 
            'chr_start' => $g->start() + $offset, 
            'chr_end'   => $g->end() + $offset, 
            'start'     => $g->start(), 
            'strand'    => $g->strand(), 
            'end'       => $g->end(), 
            'ens_ID'    => '', #$g->{'stable_id'}, 
            'label'     => $gene_label, 
            'colour'    => $gene_col, 
            'ext_DB'    => $g->external_db(), 
            'high'      => $high, 
            'type'      => $g->type() 
        }; 
    } 

##############################################################################
# Stage 2b: Retrieve all core (ensembl) genes                                #
##############################################################################
    foreach my $g (@{$gene_objs{lc($authority)}} ) { 
        my( $gene_col, $gene_label, $high);
        $high = exists $highlights{$g->stable_id()} ? 1 : 0;
        my $gene_col = $colours->{'_'.$g->external_status};
        my $gene_label = $g->external_name() || 'NOVEL';
        push @genes, {
            'chr_start' => $g->start() + $offset,
            'chr_end'   => $g->end() + $offset,
            'start'     => $g->start(),
            'strand'    => $g->strand(),
            'end'       => $g->end(),
            'ens_ID'    => $g->stable_id(),
            'label'     => $gene_label,
            'colour'    => $gene_col,
            'ext_DB'    => $g->external_db(),
            'high'      => $high
        };
    }

##############################################################################
# Stage 2d: Retrieve all RefSeq genes                                        #
##############################################################################
    foreach my $g (@{$gene_objs{'refseq'}} ) { ## Hollow genes
        my $gene_label = $g->stable_id();
        my $high = (exists $highlights{ $g->stable_id() }) ||
          exists ($highlights{$gene_label});
        my $gene_col = $colours->{'refseq'};
        push @genes, {
                'chr_start' => $g->start() + $offset,
                'chr_end'   => $g->end() + $offset,
                'start'     => $g->start(),
                'strand'    => $g->strand(),
                'end'       => $g->end(),
                'ens_ID'    => '', #$g->{'stable_id'},
                'label'     => $gene_label,
                'colour'    => $gene_col,
                'ext_DB'    => $g->external_db(),
                'high'      => $high,
                'type'      => $g->type()
        };
    }

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

	    next if $label eq '';
        my $tglyph = new Sanger::Graphics::Glyph::Text({
            'x'         => $start-1,	
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
            if( $g->{'ens_ID'} ne '' ) {
    			$tglyph->{'zmenu'}->{"Gene: $g->{'ens_ID'}"} = "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$g->{'ens_ID'}"; 
                $tglyph->{'href'} = "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$g->{'ens_ID'}" ;
            }
		}
		
        my $depth = $Config->get('gene_label_lite', 'dep');
        if ($depth > 0){ # we bump
            my $bump_start = int($tglyph->x() * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);
    
            my $bump_end = $bump_start + int($tglyph->width()*$pix_per_bp) +1;
            $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
            my $row = & Sanger::Graphics::Bump::bump_row(
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
        my $taggy = new Sanger::Graphics::Glyph::Rect({
            'x'            => $start-1,
            'y'            => $tglyph->y - 1,
            'width'        => 0,
            'height'       => 4,
            'bordercolour' => $g->{'colour'},
            'absolutey'    => 1,
        });
    
        push @gene_glyphs, $taggy;
        $taggy = new Sanger::Graphics::Glyph::Rect({
            'x'            => $start-1,
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
            my $rect2 = new Sanger::Graphics::Glyph::Rect({
                'x'         => $tglyph->x() + $font_w_bp,
                'y'         => $tglyph->y(),
                'width'     => $font_w_bp * length($label),
                'height'    => $tglyph->height(),
                'colour'    => $colours->{'hi'},
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
