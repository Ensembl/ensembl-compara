package Bio::EnsEMBL::GlyphSet::gene_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Text;
use Bump;
use EnsWeb;
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

sub checkDB {
    my $db = EnsWeb::species_defs->databases   || {};
    return $db->{$_[0]} && $db->{$_[0]}->{NAME};
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
    my $sanger_colours = { 
           'Novel_CDS'        => $Config->get('gene_lite','sanger_Novel_CDS'), 
           'Putative'         => $Config->get('gene_lite','sanger_Putative'), 
           'Known'            => $Config->get('gene_lite','sanger_Known'), 
           'Novel_Transcript' => $Config->get('gene_lite','sanger_Novel_Transcript'), 
           'Pseudogene'       => $Config->get('gene_lite','sanger_Pseudogene'), 
    }; 

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
	my $vc_start = $vc->_global_start();
    my @genes = ();
    
    if ($type eq 'all' && &checkDB('ENSEMBL_SANGER')){ 
           my $res = $vc->get_all_SangerGenes_startend_lite(); 
           foreach my $g (@$res){ 
               my( $gene_col, $gene_label, $high); 
               $high       = exists $highlights{ $g->{'stable_id'} } ? 1 : 0; 
               $gene_label = $g->{'stable_id'}; 
               $high       = 1 if(exists $highlights{ $gene_label }); 
               my $T = $g->{'type'}; 
               $T =~ s/HUMACE-//; 
               $gene_col = $sanger_colours->{ $T }; 
               push @genes, { 
                   'chr_start' => $g->{'chr_start'}, 
                   'chr_end'   => $g->{'chr_end'}, 
                   'start'     => $g->{'start'}, 
                   'strand'    => $g->{'strand'}, 
                   'end'       => $g->{'end'}, 
                   'ens_ID'    => '', #$g->{'stable_id'}, 
                   'label'     => $gene_label, 
                   'colour'    => $gene_col, 
                   'ext_DB'    => $g->{'db'}, 
                   'high'      => $high, 
                   'type'      => $g->{'type'} 
               }; 
           } 
        $Config->{'legend_features'}->{'sanger_genes'} = {
            'priority' => 1000,
            'legend'  => [
                'Sanger curated known genes'    => $sanger_colours->{'Known'},
                'Sanger curated novel CDS'      => $sanger_colours->{'Novel_CDS'},
                'Sanger curated putative'       => $sanger_colours->{'Putative'},
                'Sanger curated novel Trans'    => $sanger_colours->{'Novel_Transcript'},
                'Sanger curated pseudogenes'    => $sanger_colours->{'Pseudogene'}
            ]
        }  if(@$res>0);
    } 
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
            'high'      => $high,
            'type'      => 'ensembl'
        };
    }
    $Config->{'legend_features'}->{'genes'} = {
        'priority' => 900,
        'legend'  => [
            'EnsEMBL predicted genes (known)' => $known_col,
            'EnsEMBL predicted genes (novel)' => $unknown_col
        ]
    }  if(@$res>0);
    &eprof_end("gene-virtualgene_start-get");

    &eprof_start("gene-externalgene_start-get");
    if ($type eq 'all' && &checkDB('ENSEMBL_EMBL')){ 
        my $res = $vc->get_all_EMBLGenes_startend_lite();
        foreach my $g (@$res){
            my( $gene_col, $gene_label, $high);
            $high       = exists $highlights{ $g->{'stable_id'} } ? 1 : 0;
            $gene_label = $g->{'synonym'} || $g->{'stable_id'};
            $high       = 1 if(exists $highlights{ $gene_label });
            if($g->{'type'} eq 'pseudo') {
                $gene_col = $pseudo_col;
            } else {
                $gene_col = $ext_col;
            }
            push @genes, {
                'chr_start' => $g->{'chr_start'},
                'chr_end'   => $g->{'chr_end'},
                'start'     => $g->{'start'},
                'strand'    => $g->{'strand'},
                'end'       => $g->{'end'},
                'ens_ID'    => '', #$g->{'stable_id'},
                'label'     => $gene_label,
                'colour'    => $gene_col,
                'ext_DB'    => $g->{'db'},
                'high'      => $high,
                'type'      => $g->{'type'}
            };
        }
        $Config->{'legend_features'}->{'embl_genes'} = {
            'priority' => 800,
            'legend'  => [
                'EMBL curated genes'      => $ext_col,
                'EMBL pseudogenes'        => $pseudo_col,
            ]
        }  if(@$res>0);
    }

    &eprof_end("gene-externalgene_start-get");

    #&eprof_start("gene-render-code");

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
            if( $g->{'ens_ID'} ne '' ) {
    			$rect->{'zmenu'}->{"Gene: $g->{'ens_ID'}"} = "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$g->{'ens_ID'}"; 
                $rect->{'href'} = "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$g->{'ens_ID'}" ;
            }
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
    #&eprof_end("gene-render-code");
}

1;
        
