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

sub init_label {
    my ($this) = @_;

    my $label = new Bio::EnsEMBL::Glyph::Text({
    'text'      => 'Transcript',
    'font'      => 'Small',
    'absolutey' => 1,
    });
    $this->label($label);
}

sub _init {
    my ($self) = @_;

    my $VirtualContig = $self->{'container'};
    my $Config      = $self->{'config'};

    my $vcid        = $VirtualContig->id();
    my $scriptname  = $Config->script();
    my $y	    = 0;
    my $h	    = 8;
    my $highlights  = $self->highlights();
    my @bitmap      = undef;
    my $im_width    = $Config->image_width();
    my $colour      = $Config->get($scriptname,'transcript','unknown');
    my $type        = $Config->get($scriptname,'transcript','src');
    my @allgenes    = ();
    
    my $pix_per_bp  = $Config->transform->{'scalex'};
    my $bitmap_length = int($VirtualContig->length * $pix_per_bp);
    
    #foreach my $vg ($VirtualContig->get_all_VirtualGenes()){
    #push (@allgenes, $vg->gene());
    #}

    @allgenes = $VirtualContig->get_all_Genes_exononly();
	

    if ($type eq 'all'){
	foreach my $vg ($VirtualContig->get_all_ExternalGenes()){
	    $vg->{'_is_external'} = 1;
	    push (@allgenes, $vg);
	}
    }
	$type = undef;
	
    GENE: for my $eg (@allgenes) {
    	my $vgid = $eg->id();
        my $hi_colour = $Config->get($scriptname,'transcript','hi') if(defined $highlights && $highlights =~ /\|$vgid\|/);
		$type = $eg->type();
		#print STDERR "type: $type\n";
		
    TRANSCRIPT: for my $transcript ($eg->each_Transcript()) {

        #########
        # test transcript strand
        #
        my $tstrand = $transcript->strand_in_context($vcid);
        next TRANSCRIPT if($tstrand != $self->strand());

        #########
        # set colour for transcripts and test if we're highlighted or not
        # 
        my @dblinks = ();
        my $id = $transcript->id();
        my $gene_name;
        my ($hugo, $swisslink, $sptrembllink);
        eval {
            @dblinks = $transcript->each_DBLink();

            foreach my $DB_link ( @dblinks ){
                if( $DB_link->database() eq 'HUGO') {
                    $hugo = $DB_link;
                    last;
                }
                if( $DB_link->database() =~ /SWISS/o ) {
                    $swisslink = $DB_link;
                }
                if( $DB_link->database() eq 'SPTREMBL') {
                    $sptrembllink = $DB_link;
                }
            }

            if( $hugo ) {
                $id = $hugo->display_id();
            } elsif ( $swisslink ) {
                $id = $swisslink->display_id();
            } elsif ( $sptrembllink ) {
                $id = $sptrembllink->display_id();
            }  
        };

        if (@dblinks){
            $colour = $Config->get($scriptname,'transcript','known');
        } else {
            $colour = $Config->get($scriptname,'transcript','unknown');
        }
        if ($eg->{'_is_external'}){
            $colour = $Config->get($scriptname,'transcript','ext');
        }
        if ($type eq "pseudo"){
            $colour = $Config->get($scriptname,'transcript','pseudo');
        }
        
        my $tid = $transcript->id();
        my $pid = $tid;

        my $Composite = new Bio::EnsEMBL::Glyph::Composite({});
		
		if ($tid !~ /ENST/o){
			# if we have an EMBL external transcript we need different links...
			if($tid !~ /dJ/o){
        		$Composite->{'zmenu'}  = {
            		'caption'	    	=> "EMBL: $tid",
            		'More information'  => "http://www.ebi.ac.uk/cgi-bin/emblfetch?$tid",
            		'EMBL curated transcript'  => "",
	    		};
			} else {
				my $URL = ExtURL->new();
				my $url = $URL->get_url('EMBLGENE', $tid);
				
        		$Composite->{'zmenu'}  = {
            		'caption'	    => "EMBL: $tid",
            		'EMBL curated transcript'  => "",
					"$tid"			=> $url
	    		};
			}
			if($type eq "pseudo"){
				$tid =~ s/(.*?)\.\d+/$1/;
        		$Composite->{'zmenu'}  = {
            		'caption'	    	=> "EMBL: $tid",
            		'More information'  => "http://www.ebi.ac.uk/cgi-bin/emblfetch?$tid",
            		'EMBL curated pseudogene'  => "",
	    		};
			}			
		} else {
			# we have a normal Ensembl transcript...
        	$Composite->{'zmenu'}  = {
            	'caption'					   => $id,
            	'00:Ensembl transcript'    	   => "",
             	'01:Transcript information'    => "/perl/geneview?gene=$vgid",
           		'02:Protein information'       => "/perl/protview?peptide=$pid",
            	'05:Protein sequence (FASTA)'  => "/perl/dumpview?type=peptide&id=$tid",
            	'03:Supporting evidence'       => "/perl/transview?transcript=$tid",
            	'04:Expression information'    => "/perl/sageview?alias=$vgid",
            	'06:cDNA sequence'             => "/perl/dumpview?type=cdna&id=$tid",
	    	};
		}
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
            #'id'        => $exon->id(),
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
        my $bump_start = int($Composite->x * $pix_per_bp);
        $bump_start = 0 if ($bump_start < 0);

        my $bump_end = $bump_start + int($Composite->width * $pix_per_bp);
        if ($bump_end > $bitmap_length){$bump_end = $bitmap_length};

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
        $self->push($Composite);
    }
    }
}

1;
