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
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
	'text'      => 'Genes',
	'font'      => 'Small',
	'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == -1);

    my $VirtualContig = $self->{'container'};
    my $Config        = $self->{'config'};
    my $y             = 0;
    my $h             = 8;
    my $highlights    = $self->highlights();
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $type          = $Config->get('gene', 'src');
    my @allgenes      = ();

#    &eprof_start("gene-virtualgene_start-get");
    push @allgenes, $VirtualContig->get_all_VirtualGenes_startend();
#    &eprof_end("gene-virtualgene_start-get");

#    &eprof_start("gene-externalgene_start-get");
#    if ($type eq 'all'){
	foreach my $vg ($VirtualContig->get_all_ExternalGenes()){
	    $vg->{'_is_external'} = 1;
	    push (@allgenes, $vg);
	}
#    }
#    &eprof_end("gene-externalgene_start-get");

#    &eprof_start("gene-render-code");
    my $ext_col       = $Config->get('gene','ext');
    my $known_col     = $Config->get('gene','known');
    my $unknown_col   = $Config->get('gene','unknown');
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($VirtualContig->length * $pix_per_bp);

    foreach my $vg (@allgenes) {

	my $vgid  = $vg->id();
	my ($start, $end, $colour);

	if($vg->isa("Bio::EnsEMBL::VirtualGene")) {
	    $colour   = $vg->gene->is_known()?$known_col:$unknown_col;

#	    my @temp_geneDBlinks = $vg->gene->each_DBLink();
#	    my @ids;
#	    
#	    foreach my $DB_link ( @temp_geneDBlinks ){
#		push @ids, $DB_link->display_id();
#	    }
#	    push @ids, $vg->id();
#	    
#	    my %union = ();
#	    my %isect = ();
#	    for my $e (@ids, $self->highlights()) { $union{$e}++ && $isect{$e}++ }
#	    $colour = $Config->get('gene', 'hi') if(scalar keys %isect > 0);

	    $start    = $vg->start();
	    $end      = $vg->end();
	} else {
	    # for the moment we are ignoring external genes...
	    #next;
	    # EXTERNAL ANNOYING GENES
	    $colour   = $ext_col;
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
            if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};
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
	$self->push($rect);
    }
#    &eprof_end("gene-render-code");
    
}

1;
