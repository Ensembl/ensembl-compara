package Bio::EnsEMBL::GlyphSet::transcript;
use strict;
use vars qw(@ISA);
use lib "..";
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bio::EnsEMBL::Glyph::Line;
use Bump;

sub _init {
    my ($this, $VirtualContig, $Config) = @_;

    my $y             = 0;
    my $h             = 8;
    my $highlights    = $this->highlights();
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $bitmap_length = $VirtualContig->length();
    my $colour        = $Config->get($Config->script(),'transcript','unknown');
    my $type          = $Config->get($Config->script(),'transcript','src');
    my @allgenes      = ();
	
    foreach my $vg ($VirtualContig->get_all_VirtualGenes()){
	push (@allgenes, $vg->gene());
    }

    if ($type eq 'all'){
	foreach my $vg ($VirtualContig->get_all_ExternalGenes()){
	    $vg->{'_is_external'} = 1;
	    push (@allgenes, $vg);
	}
    }

    GENE: for my $eg (@allgenes) {
	my $vgid = $eg->id();
    	my $hi_colour = $Config->get($Config->script(),'transcript','hi') if(defined $highlights && $highlights =~ /\|$vgid\|/);

	TRANSCRIPT: for my $transcript ($eg->each_Transcript()) {

    	#########
    	# test transcript strand
    	#
    	my $tstrand = $transcript->strand_in_context($VirtualContig->id());
    	next TRANSCRIPT if($tstrand != $this->strand());

    	#########
    	# set colour for transcripts and test if we're highlighted or not
    	# 
    	my @dblinks = ();
    	my $id = undef;
	    my $gene_name;
	    my ($hugo, $swisslink, $sptrembllink);
	    eval {
		@dblinks = $transcript->each_DBLink();

		foreach my $DB_link ( @dblinks ){
		    if( $DB_link->database eq 'HUGO') {
			$hugo = $DB_link;
			last;
		    }
		    if( $DB_link->database =~ /SWISS/o ) {
			$swisslink = $DB_link;
		    }
		    if( $DB_link->database eq 'SPTREMBL') {
			$sptrembllink = $DB_link;
		    }
		}

		if( $hugo ) {
		    $id = $hugo->primary_id;
		} elsif ( $swisslink ) {
		    $id = $swisslink->primary_id;
		} elsif ( $sptrembllink ) {
		    $id = $sptrembllink->primary_id;
		}  else {
		    $id = 'unknown';
		}
            };

	    my $colour;

	    if (@dblinks){
		$colour = $Config->get($Config->script(),'transcript','known');
	    } else {
		$colour = $Config->get($Config->script(),'transcript','unknown');
	    }
	    if ($eg->{'_is_external'}){
		$colour = $Config->get($Config->script(),'transcript','ext');
	    }
	    my $Composite = new Bio::EnsEMBL::Glyph::Composite({
		'id'     => $transcript->id(),
#		'bordercolour' => $colour,
		'zmenu'  => {
		    'caption'     => $transcript->id(),
		    '01:kung'     => 'opt1',
		    '02:foo'      => 'opt2',
		    '03:fighting' => 'opt3'
		},
	    });

	    my @exons = $transcript->each_Exon_in_context($VirtualContig->id());

	    my ($start_screwed, $end_screwed);
	    if($tstrand != -1) {
		$start_screwed = $transcript->is_start_exon_in_context($VirtualContig->id());
		$end_screwed   = $transcript->is_end_exon_in_context($VirtualContig->id());
	    } else {
		$end_screwed   = $transcript->is_start_exon_in_context($VirtualContig->id());
		$start_screwed = $transcript->is_end_exon_in_context($VirtualContig->id());
		@exons = reverse @exons;
	    }

	    my $start_exon = $exons[0];
	    my $end_exon   = $exons[(scalar @exons) -1];

	    my $previous_endx;

	    #########
	    # draw anything trailing off the beginning
	    #
	    if(defined $start_screwed && $start_screwed == 0) {
		my $clip = new Bio::EnsEMBL::Glyph::Line({
		    'x'         => 0,
		    'y'         => $y+int($h/2),
		    'width'     => $start_exon->start(),
		    'height'    => 0,
		    'absolutey' => 1,
		    'colour'    => $colour,
		    'dotted'    => 1,
		});
		$Composite->push($clip);
		$previous_endx = $start_exon->end();
	    }

    	    EXON: for my $exon (@exons) {
		#########
		# otherwise we're on the VC and everything's ok
		#
		my $x = $exon->start();
		my $w = $exon->end() - $x;

		my $rect = new Bio::EnsEMBL::Glyph::Rect({
		    'x'         => $x,
		    'y'         => $y,
		    'width'     => $w,
		    'height'    => $h,
		    'colour'    => $colour,
		    'absolutey' => 1,
		});

		my $intron = new Bio::EnsEMBL::Glyph::Intron({
		    'x'         => $previous_endx,
		    'y'         => $y,
		    'width'     => ($x - $previous_endx),
		    'height'    => $h,
		    'id'        => $exon->id(),
		    'colour'    => $colour,
		    'absolutey' => 1,
		    'strand'    => $tstrand,
		}) if(defined $previous_endx);

		$Composite->push($rect);
		$Composite->push($intron);

		$previous_endx = $exon->end();
	    }

	    #########
	    # draw anything trailing off the end
	    #
	    if(defined $end_screwed && $end_screwed == 0) {
		my $clip = new Bio::EnsEMBL::Glyph::Line({
		    'x'         => $previous_endx,
		    'width'     => $VirtualContig->length() - $previous_endx,
		    'y'         => $y+int($h/2),
		    'height'    => 0,
		    'colour'    => $colour,
		    'absolutey' => 1,
		    'dotted'    => 1,
		});
		$Composite->push($clip);
	    }


	    #########
	    # bump it baby, yeah!
	    # bump-nology!
	    #
	    my $bump_start = $Composite->x();
	    $bump_start = 0 if ($bump_start < 0);

	    my $bump_end = $bump_start + ($Composite->width());
	    next if $bump_end > $bitmap_length;

	    my $row = &Bump::bump_row(      
		$bump_start,
		$bump_end,
		$bitmap_length,
		\@bitmap
	    );

	    #########
	    # shift the composite container by however much we're bumped
	    #
	    $Composite->y($Composite->y() + (1.5 * $row * $h * -$tstrand));
	    $this->push($Composite);
	}
    }
}

1;
