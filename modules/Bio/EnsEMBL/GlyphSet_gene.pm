package Bio::EnsEMBL::GlyphSet_gene;
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
        'text'      => $self->my_label(),
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
    my $logic_name = $self->logic_name();
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


    my $known_col     = $Config->get('_colours','_KNOWN');
    my $xref_col      = $Config->get('_colours','_XREF');
    my $pred_col      = $Config->get('_colours','PRED');
    my $hi_col        = $Config->get('_colours','hi');
    my $unknown_col   = $Config->get('_colours','_');
    my $ext_col       = $Config->get('_colours','_');
    my $pseudo_col    = $Config->get('_colours','_');
   

 my $rat_colours = { 
       'refseq' => $Config->get('_colours','_XREF'), 
    }; 

    my $sanger_colours = { 
           'Novel_CDS'        => $Config->get('_colours','Novel_CDS'), 
           'Putative'         => $Config->get('_colours','Putative'), 
           'Known'            => $Config->get('_colours','Known'), 
           'Novel_Transcript' => $Config->get('_colours','Novel_Transcript'), 
           'Pseudogene'       => $Config->get('_colours','Pseudogene'), 
	   'Ig_Segment'       => $Config->get('_colours','Ig_Segment'), 	  
	   'Ig_Pseudogene_Segment'   =>$Config->get('_colours','Ig_Pseudogene') , 
	   'Predicted_Gene'   => $Config->get('_colours','Predicted_Gene'),
	   'Transposon'	      => $Config->get('_colours','Transposon'),
	   'Polymorphic'      => $Config->get('_colours','Polymorphic'),
    }; 

    my $gene_type_names = { 
           'Novel_CDS'        => 'Curated novel CDS',
           'Putative'         => 'Curated putative',
           'Known'            => 'Curated known genes',
           'Novel_Transcript' => 'Curated novel Trans',
           'Pseudogene'       => 'Curated pseudogenes',
	   'Ig_Segment'       => 'Curated Ig Segment',
	   'Ig_Pseudogene_Segment'   => 'Curated Ig Pseudogene',
	   'Predicted_Gene'   => 'Curated predicted',
	   'Transposon'	      => 'Curated Transposon',
	   'Polymorphic'      => 'Curated Polymorphic',
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
    warn( $self->logic_name );
    foreach my $g (@{$vc->get_all_Genes($self->logic_name())} ) {
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
	# push all gene types present in the DB to the legend array
	$Config->{'legend_features'}->{'sanger_genes'} = {
	    'priority' => 1000,
	    'legend'  => [],
	};
	foreach my $gene_type (sort keys %{ EnsWeb::species_defs->VEGA_GENE_TYPES || {}} ) {
	    push(@{$Config->{'legend_features'}->{'sanger_genes'}->{'legend'}}, "$gene_type_names->{$gene_type}" => $sanger_colours->{$gene_type} );
	    
	}
    } 

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
	    
'caption' 	=> $g->{'label'},
"bp: $g->{'chr_start'}-$g->{'chr_end'}" 			=> '',
 "length: ".($g->{'chr_end'}-$g->{'chr_start'}+1) 	=> ''
			}; 


            if( $g->{'ens_ID'} ne '' ) {
  		$rect->{'zmenu'}->{"Gene: $g->{'ens_ID'}"} = "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$g->{'ens_ID'}"; 

                $rect->{'href'} = "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$g->{'ens_ID'}" ;
            }
		}
    

        my $depth = $self->my_depth() ; 
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
