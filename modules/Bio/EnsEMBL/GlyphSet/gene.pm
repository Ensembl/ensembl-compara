package Bio::EnsEMBL::GlyphSet::gene;
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

    my $VirtualContig = $self->{'container'};
    my $Config        = $self->{'config'};
    my $y             = 0;
    my $h             = 8;
    my %highlights;
    @highlights{$self->highlights} = ();    # build hashkeys of highlight list
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $type          = $Config->get('gene', 'src');
    my @allgenes      = ();

    #&eprof_start("gene-virtualgene_start-get");
    push @allgenes, $VirtualContig->get_all_VirtualGenes_startend();
    #&eprof_end("gene-virtualgene_start-get");

#    #&eprof_start("gene-externalgene_start-get");
#    if ($type eq 'all'){
#	foreach my $vg ($VirtualContig->get_all_ExternalGenes()){
#	    $vg->{'_is_external'} = 1;
#	    push (@allgenes, $vg);
#	}
#    }
    #&eprof_end("gene-externalgene_start-get");

#    #&eprof_start("gene-render-code");
    my $ext_col       = $Config->get('gene','ext');
    my $known_col     = $Config->get('gene','known');
    my $hi_col        = $Config->get('gene','hi');
    my $unknown_col   = $Config->get('gene','unknown');
    my $pseudo_col    = $Config->get('gene','pseudo');
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($VirtualContig->length * $pix_per_bp);

    my @gene_glyphs = ();
    foreach my $vg (@allgenes) {

    	my $vgid  = $vg->id();
    	my ($label, $start, $end, $colour, $highlight, $genetype);
        my $highlight='';
        if($vg->isa("Bio::EnsEMBL::VirtualGene")) {
            ($genetype, $label, $highlight, $start, $end) = $self->virtualGene_details( $vg, %highlights );
            $colour = $genetype eq 'known' ? $known_col : $unknown_col;
        } else { # EXTERNAL ANNOYING GENES
            ($genetype, $label, $highlight, $start, $end) = $self->externalGene_details( $vg, $VirtualContig->id, %highlights );
            $colour   = $genetype eq 'pseudo' ? $pseudo_col : $ext_col;
        }
    
        my $rect = new Bio::EnsEMBL::Glyph::Rect({
            'x'         => $start,
        	'y'         => $y,
        	'width'     => $end - $start,
        	'height'    => $h,
        	'colour'    => $colour,
        	'absolutey' => 1,
        });
    
    	my $depth = $Config->get('gene', 'dep');
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
        if($highlight) {
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
