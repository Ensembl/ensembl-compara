package Bio::EnsEMBL::GlyphSet::gene_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use  Sanger::Graphics::Bump;
use EnsWeb;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);

sub init_label {
    my ($self) = @_;
        return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Sanger::Graphics::Glyph::Text({
        'text'      => 'Genes',
        'font'      => 'Small',
        'absolutey' => 1,
        'href'      => qq[javascript:X=window.open(\'/$ENV{'ENSEMBL_SPECIES'}/helpview?se=1&kw=$ENV{'ENSEMBL_SCRIPT'}#gene_lite\',\'helpview\',\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\');X.focus();void(0)],

        'zmenu'     => {
            'caption'                     => 'HELP',
            "01:Track information..."     =>
qq[javascript:X=window.open(\\\'/$ENV{'ENSEMBL_SPECIES'}/helpview?se=1&kw=$ENV{'ENSEMBL_SCRIPT'}#gene_lite\\\',\\\'helpview\\\',\\\'height=400,width=500,left=100,screenX=100,top=100,screenY=100,resizable,scrollbars=yes\\\');X.focus();void(0)]
        }

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
    my $rat_colours = { 
       'refseq' => $Config->get('gene_lite','refseq'), 
    }; 

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
    my $show_navigation 
      =  $navigation eq 'on' && ( $vc->length() < $max_length_nav * 1001 );
    
    #First of all let us deal with all the EnsEMBL genes....
    my $vc_start = $vc->chr_start();
    my $offset = $vc_start - 1;
    my @genes = ();

    #
    # Draw all of the Vega Genes
    #
    my $F = 0;
    foreach my $g (@{$vc->get_all_Genes_by_source( "sanger",1 )} ) {
      $F++;
      my $genelabel = $g->stable_id(); 
      my $high = exists $highlights{$genelabel};
      my $type = $g->type();
      $type =~ s/HUMACE-//;

      my $gene_col = $sanger_colours->{ $type };

      push @genes, { 
		   'chr_start' => $g->start() + $offset,
                   'chr_end'   => $g->end() + $offset,
                   'start'     => $g->start(), 
                   'strand'    => $g->strand(), 
                   'end'       => $g->end(), 
                   'ens_ID'    => $g->stable_id(), 
                   'label'     => $genelabel, 
                   'colour'    => $gene_col, 
                   'ext_DB'    => $g->external_db(), 
                   'high'      => $high, 
                   'type'      => $g->type()
            };
    } 
    if($F>0) {
      $Config->{'legend_features'}->{'sanger_genes'} = {
       'priority' => 1000,
       'legend'  => [
	 'Sanger curated known genes'=> $sanger_colours->{'Known'},
         'Sanger curated novel CDS'  => $sanger_colours->{'Novel_CDS'},
         'Sanger curated putative'   => $sanger_colours->{'Putative'},
         'Sanger curated novel Trans'=> $sanger_colours->{'Novel_Transcript'},
         'Sanger curated pseudogenes'=> $sanger_colours->{'Pseudogene'} ] };
    } 


    #
    # Draw all of the Core (ensembl) genes
    #
    $F=0;
    foreach my $g (@{$vc->get_all_Genes_by_source( "core",1 )} ) {
      $F++;
      my $high = (exists $highlights{ $g->stable_id() }) 
              || (exists $highlights{ $g->external_name() });
      my ($gene_col, $gene_label);
      $gene_label = $g->external_name;
      if(defined $gene_label && $gene_label ne '') {
	$gene_col = $known_col;
      } else {
	$gene_col = $unknown_col;
	$gene_label = 'NOVEL'; 
      }
      push @genes, {
            'chr_start' => $g->start + $offset,
            'chr_end'   => $g->end + $offset,
            'start'     => $g->start(),
            'strand'    => $g->strand(),
            'end'       => $g->end(),
            'ens_ID'    => '', #$g->stable_id(),
            'label'     => $gene_label,
            'colour'    => $gene_col,
            'ext_DB'    => $g->external_db(),
            'high'      => $high,
            'type'      => 'ensembl' };
    }
    if($F>0) {
      $Config->{'legend_features'}->{'genes'} = {
	'priority' => 900,
        'legend'  => [
            'EnsEMBL predicted genes (known)' => $known_col,
            'EnsEMBL predicted genes (novel)' => $unknown_col ] };
    }

    &eprof_end("gene-virtualgene_start-get");

    &eprof_start("gene-externalgene_start-get");

    #
    # Draw all EMBL Genes
    #
    $F=0;
    foreach my $g (@{$vc->get_all_Genes_by_source( "embl",1 )} ) {
      $F++;
      my $gene_label = $g->external_name() || $g->stable_id();
      
      my $high = exists $highlights{ $g->external_name() } ||
	exists $highlights{ $g->stable_id() };

      my $gene_col;
      if($g->type() eq 'pseudo') {
	$gene_col = $pseudo_col;
      } else {
	$gene_col = $ext_col;
      }

      push @genes, {
		'chr_start' => $g->start + $offset,
                'chr_end'   => $g->end + $offset,
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

    if($F>0) {
      $Config->{'legend_features'}->{'embl_genes'} = {
            'priority' => 800,
            'legend'  => [
                'EMBL curated genes' => $ext_col,
                'EMBL pseudogenes'   => $pseudo_col ] };
    }

    #
    # Draw all RefSeq Genes
    #
    $F=0;
    foreach my $g (@{$vc->get_all_Genes_by_source( "refseq",1 )} ) {
      $F++;
      my $gene_label = $g->external_name() || $g->stable_id();

      my $high = exists $highlights{ $g->external_name() } ||
        exists $highlights{ $g->stable_id() };

      my $gene_col = $rat_colours->{'refseq'};

      push @genes, {
                'chr_start' => $g->start + $offset,
                'chr_end'   => $g->end + $offset,
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

    if($F>0) {
      $Config->{'legend_features'}->{'refseq_genes'} = {
            'priority' => 801,
            'legend'  => [
                'RefSeq proteins' => $rat_colours->{'refseq'},
            ] };
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

        my $rect = new Sanger::Graphics::Glyph::Rect({
                'x'         => $start-1,
                'y'         => 0,
                'width'     => $end - $start+1,
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
            my $row = & Sanger::Graphics::Bump::bump_row(
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
            my $rect2 = new Sanger::Graphics::Glyph::Rect({
                'x'         => $start -1 - 1/$pix_per_bp,
                'y'         => $rect->y()-1,
                'width'     => $end - $start  +1 + 2/$pix_per_bp,
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
        
