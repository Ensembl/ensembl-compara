package Bio::EnsEMBL::GlyphSet::gene_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);

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
    my ($self) = @_;

    return unless ($self->strand() == -1);

    my $vc = $self->{'container'};
    my $Config        = $self->{'config'};
    my $y             = 0;
    my $h             = 8;
    my %highlights;
    @highlights{$self->highlights} = ();    # build hashkeys of highlight list
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $vc_length     = $Config->image_width();
    my $type          = $Config->get('gene_lite', 'src');
    my @allgenes      = ();


    # call on ensembl lite to give us the details of all
    # genes in the virtual contig
    &eprof_start("gene-virtualgene_start-get");
    my $known_col     = $Config->get('gene_lite','known');
    my $hi_col        = $Config->get('gene_lite','hi');
    my $unknown_col   = $Config->get('gene_lite','unknown');
    my $ext_col       = $Config->get('gene_lite','ext');
    my $pseudo_col    = $Config->get('gene_lite','pseudo');
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $vc_length     = $vc->length;
    my $bitmap_length = int( $vc_length * $pix_per_bp );
    my $max_length     = $Config->get( 'gene_lite', 'threshold' ) || 2000000;
    my $navigation     = $Config->get( 'gene_lite', 'navigation' ) || 'off';
    my $max_length_nav = $Config->get( 'gene_lite', 'navigation_threshold' ) || 200000;

    if( $vc_length > ($max_length*1001)) {
        $self->errorTrack("Genes only displayed for less than $max_length Kb.");
        return;
    }
	my $show_navigation =  $navigation eq 'on' && ( $vc->length() < $max_length_nav * 1001 );
    
#First of all let us deal with all the EnsEMBL genes....
    my $res = $vc->get_all_VirtualGenes_startend_lite();

	my $vc_start = $vc->_global_start();
    my @genes = ();
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
                'chr_start'  => $_->{'chr_start'},
                'chr_end'    => $_->{'chr_end'},
                'start'  => $_->{'start'},
                'end'    => $_->{'end'},
                'ens_ID' => $_->{'stable_id'},
                'label'  => $gene_label,
                'colour' => $gene_col,
                'ext_DB' => $_->{'db'},
                'high'   => $high
        };
    }
    &eprof_end("gene-virtualgene_start-get");

    &eprof_start("gene-externalgene_start-get");
    if ($type eq 'all'){
       foreach my $vg ($vc->get_all_ExternalGenes()){
               my ($genetype, $label, $highlight, $start, $end) = $self->externalGene_details( $vg, $vc->id, %highlights );
               my $colour   = $genetype eq 'pseudo' ? $pseudo_col : $ext_col;
                push @genes, {
                        'chr_start' =>$start+$vc_start-1,
                        'chr_end'   =>$end+$vc_start-1,
                        'start' =>$start,
                        'end'   =>$end,
                        'ens_ID'=>'',
                        'label' =>$label,
                        'colour'=>$colour,
                        'ext_DB'=>$genetype,
                        'high'  =>$highlight
                };
        }
	}
    &eprof_end("gene-externalgene_start-get");

#    #&eprof_start("gene-render-code");

    my @gene_glyphs = ();
    foreach my $g (@genes) {
        my $start = $g->{'start'};
        my $end   = $g->{'end'};
		
		next if($end < 1 || $start > $vc_length);
        $start = 1 if $start<1;
        $end = $vc_length if $end > $vc_length;

        my $rect = new Bio::EnsEMBL::Glyph::Rect({
                'x'         => $start,
                'y'         => 0,
                'width'     => $end - $start,
                'height'    => $h,
                'colour'    => $g->{'colour'},
                'absolutey' => 1,
        });
		if($show_navigation) {
			$rect->{'zmenu'} = {
				'caption' 											=> $g->{'label'},
				"bp: $g->{'chr_start'}-$g->{'chr_end'}" 			=> '',
				"length: ".($g->{'chr_end'}-$g->{'chr_start'}+1) 	=> ''
			};
			$rect->{'zmenu'}->{"Gene: $g->{'ens_ID'}"} = "/$ENV{'ensembl_species'}/geneview?gene=$g->{'ens_ID'}" if $g->{'ens_ID'} ne '';
		}
    
        my $depth = $Config->get('gene_lite', 'dep');
        if ($depth > 0){ # we bump
            my $bump_start = int($rect->x() * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);
    
            my $bump_end = $bump_start + int($rect->width()*$pix_per_bp) +1;
            $bump_end = $bitmap_length if ($bump_end > $bitmap_length);
            my $row = &Bump::bump_row(
                $bump_start,
                        $bump_end,
                        $bitmap_length,
                        \@bitmap
            );
    
            #next if $row > $depth;
            $rect->y($rect->y() + (6 * $row ));
            $rect->height(4);
        }
        push @gene_glyphs, $rect;
        if($g->{'high'}) {
            my $rect2 = new Bio::EnsEMBL::Glyph::Rect({
                'x'         => $start - 1/$pix_per_bp,
                'y'         => $rect->y()-1,
                'width'     => $end - $start  + 2/$pix_per_bp,
                'height'    => $rect->height()+2,
                'colour'    => $hi_col,
                'absolutey' => 1,
            });
            $self->push($rect2);
        }
    }

    foreach( @gene_glyphs) {
        $self->push($_);
    }
#    #&eprof_end("gene-render-code");
}

1;
        
