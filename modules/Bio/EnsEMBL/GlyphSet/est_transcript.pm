package Bio::EnsEMBL::GlyphSet::est_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Bio::EnsEMBL::Glyph::Rect;
use Bio::EnsEMBL::Glyph::Intron;
use Bio::EnsEMBL::Glyph::Text;
use Bio::EnsEMBL::Glyph::Composite;
use Bio::EnsEMBL::Glyph::Line;
use Bump;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);


sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    
    my $label_text = 'EST Transcr.';

    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => $label_text,
        'font'      => 'Small',
        'absolutey' => 1,
    });

    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my $type = $self->check(); 
    return unless defined $type;
    my $Config        = $self->{'config'};
    my $container     = $self->{'container'};
    my $y             = 0;
    my $h             = 8;
    my $vcid          = $container->id();
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $colour	      = $Config->get('est_transcript','col');
    my @allgenes      = ();
    my $fontname      = "Tiny";    
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($Config->container_width() * $pix_per_bp);
    my $URL = ExtURL->new();
 
    foreach my $vg ( $container->get_all_ExternalGenes ) {
	next unless $vg->type eq "genomewise";
	push @allgenes, $vg;
    }
    unless (scalar @allgenes > 0){
	if( $Config->get('_settings','opt_empty_tracks')!=0) {
	    $self->errorTrack( "No ".$self->error_track_name()." in this region" );
	}
	return;
    }
    my $PREFIX = "^".EnsWeb::species_defs->ENSEMBL_PREFIX."T";
    
GENE:
    for my $eg (@allgenes) {
        #$type = $eg->type();
	# next unless $type =~/^(genebuild|genewise|HUMACE|merged)/;
	#next unless $type =~/^HUMACE/;
      
TRANSCRIPT:
        for my $transcript ($eg->each_Transcript()) {
	    ########## test transcript strand
	    my $tstrand = $transcript->strand_in_context($vcid);
	    next TRANSCRIPT if($tstrand != $self->strand());
	    my @dblinks = ();
	    my $tid = $transcript->dbID();
	    eval {
		@dblinks = $transcript->each_DBLink();
	    };
	    my $Composite = new Bio::EnsEMBL::Glyph::Composite({});
	    #$colour = $sanger_colours->{$colour};
	    $Composite->{'href'} = qq(/$ENV{'ENSEMBL_SPECIES'}/est_transview?transcript=$tid);
	    my %zmenu = (
		'caption'           => "EST transcript",
		"01:Transcript data" => $Composite->{'href'},
	    );
	    $Composite->{'zmenu'} = \%zmenu;
	    my @exons = $transcript->each_Exon_in_context($vcid);
    
            my ($start_screwed, $end_screwed);
            if($tstrand != -1) {
                $start_screwed = $transcript->is_start_exon_in_context($vcid);
                $end_screwed   = $transcript->is_end_exon_in_context($vcid);
            } else {
                $end_screwed   = $transcript->is_start_exon_in_context($vcid);
                $start_screwed = $transcript->is_end_exon_in_context($vcid);
                @exons = reverse @exons;
            }
            my $start_exon = $exons[0];
            my $end_exon   = $exons[-1];
    
            my $previous_endx;
    
            ########## draw anything trailing off the beginning
            if(defined $start_screwed && $start_screwed == 0) {
                my $clip1 = new Bio::EnsEMBL::Glyph::Line({
                    'x'         => 0,
                    'y'         => $y+int($h/2),
                    'width'     => $start_exon->start(),
                    'height'    => 0,
                    'absolutey' => 1,
                    'colour'    => $colour,
                    'dotted'    => 1,
                });
                $Composite->push($clip1);
                ########## fix it relative to the rest of the transcript
                $clip1->y($clip1->y() - int($h/2));
                $previous_endx = $start_exon->end();
            }
    
EXON: 
            for my $exon (@exons) {
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
                    'colour'    => $colour,
                    'absolutey' => 1,
                    'strand'    => $tstrand,
                }) if(defined $previous_endx);
      
                $Composite->push($rect);
                $Composite->push($intron);
      
                $previous_endx = $exon->end();
            }
    
            ########## draw anything trailing off the end
            if(defined $end_screwed && $end_screwed == 0) {
                my $clip2 = new Bio::EnsEMBL::Glyph::Line({
                    'x'         => $previous_endx,
                    'width'     => $container->length() - $previous_endx,
                    'y'         => $y+int($h/2),
                    'height'    => 0,
                    'colour'    => $colour,
                    'absolutey' => 1,
                    'dotted'    => 1,
                });
                $Composite->push($clip2);
            } 
            my $bump_height = 1.5 * $h;
            
            ########## bump it baby, yeah!
            # bump-nology!
            #
            my $bump_start = int($Composite->x * $pix_per_bp);
            $bump_start = 0 if ($bump_start < 0);
    
            my $bump_end = $bump_start + int($Composite->width * $pix_per_bp)+1;
            if ($bump_end > $bitmap_length) { $bump_end = $bitmap_length };
    
            my $row = &Bump::bump_row(
                $bump_start,
                $bump_end,
                $bitmap_length,
                \@bitmap
            );
    
            #########
            # shift the composite container by however much we're bumped
            #
            $Composite->y($Composite->y() - $tstrand * $bump_height * $row);
            $self->push($Composite);
        } #foreach transcript
    } # foreach gene
}

sub error_track_name { return 'EST predicted transcripts'; }

1;
