package Bio::EnsEMBL::GlyphSet::transcript;
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
    
    my $label_text = $self->{'config'}->{'_draw_single_Transcript'} || 'Transcript';

    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => $label_text,
        'font'      => 'Small',
        'absolutey' => 1,
    });

    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my $Config        = $self->{'config'};
    my $container     = $self->{'container'};
    my $target        = $Config->{'_draw_single_Transcript'};
    my $target_gene   = $Config->{'geneid'};
    my $y             = 0;
    my $h             = $target ? 30 : 8;   #Single transcript mode - set height to 30 - width to 8!
    my $vcid          = $container->id();
    my %highlights;
    @highlights{$self->highlights} = ();    # build hashkeys of highlight list
    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $unknown_colour= $Config->get('transcript','unknown');
    my $known_colour  = $Config->get('transcript','known');
    my $pseudo_colour = $Config->get('transcript','pseudo');
    my $ext_colour    = $Config->get('transcript','ext');
    my $hi_colour     = $Config->get('transcript','hi');
    my $superhi_colour= $Config->get('transcript','superhi');
    my $type          = $Config->get('transcript','src');
    my @allgenes      = ();
    my $fontname      = "Tiny";    
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($Config->container_width() * $pix_per_bp);
	my $URL = ExtURL->new();
 
    my $colour;
    #&eprof_start('transcript - get_all_Genes_exononly()');
    @allgenes = $container->get_all_Genes_exononly();
    #&eprof_end('transcript - get_all_Genes_exononly()');
    #&eprof_start('transcript - get_all_ExternalGenes()');
    unless($target) { # Skip in single transcript mode
        if ($type eq 'all'){
            foreach my $vg ( $container->get_all_ExternalGenes() ) {
                next if $vg->type =~/^(genebuild|genewise|HUMACE|merged)/; # Skip sanger genes
                $vg->{'_is_external'} = 1;
                push (@allgenes, $vg);
            }
        } 
    }                 # end of Skip in single transcript mode
    #&eprof_end('transcript - get_all_ExternalGenes()');
    $type = undef;
    my $PREFIX = "^".EnsWeb::species_defs->ENSEMBL_PREFIX."T";
    
GENE:
    my $count = 0;
    for my $eg (@allgenes) {
        my $vgid = $eg->stable_id();
        next if ($target_gene && ($vgid ne $target_gene));
        my $highlight_gene = exists $highlights{$vgid} ? 1 : 0;
        my $gene_label;
        eval {
            my @dblinks = $eg->each_DBLink();
            unless( $target ) { #Skip in single transcript mode
                ($gene_label, $highlight_gene) = $self->_label_highlight($vgid, $highlight_gene, \%highlights, \@dblinks)
            }                   #end of Skip in single transcript mode
        };
        $type = $eg->type();
      
#        print STDERR sprintf( "%-10s %-20s %-20s %-20s\n",'GENE:',$vgid,$type, $gene_label );
TRANSCRIPT:
        for my $transcript ($eg->each_Transcript()) {
            next if ($target && ($transcript->stable_id() ne $target) );
        ########## test transcript strand

            my $tstrand = $transcript->strand_in_context($vcid);
            next TRANSCRIPT if($tstrand != $self->strand());
    
        ########## set colour for transcripts and test if we're highlighted or not
            my @dblinks = ();
            my $tid = $transcript->stable_id();
            my $p   = $transcript->translation;
            my $pid = $p ? $p->stable_id() : $tid;
            my $id = $tid;
            my $highlight = $highlight_gene;
            my $superhighlight = exists $highlights{$tid} ? 1 : 0;
            eval {
                @dblinks = $transcript->each_DBLink();
                unless( $target ) { #Skip in single transcript mode
                    ($id, $highlight) = $self->_label_highlight($tid, $highlight, \%highlights, \@dblinks)
                }                   #end of Skip in single transcript mode
            };
      
            my $Composite = new Bio::EnsEMBL::Glyph::Composite({});
            $colour = @dblinks ? $known_colour : $unknown_colour;
	           unless( $target ) {     #Skip this next chunk if single transcript mode
                if ($eg->{'_is_external'}) {
                    $colour = $type eq "pseudo" ? $pseudo_colour : $ext_colour;
                }
                if( $Config->{'_href_only'} eq '#tid' ) {
                    $Composite->{'href'} = qq(#$tid);
                } elsif ($tid !~ /$PREFIX/o){
					my %zmenu = (
                            'caption'           => "EMBL: $tid",
						    '01:EMBL curated '.($type eq 'pseudo' ? 'pseudogene' : 'transcript') => ''
					);
                    @dblinks = $transcript->each_DBLink();
                    if (@dblinks){
                    	foreach my $DB_link ( @dblinks ){
							my $DB = $DB_link->database();
							my $ID = $DB_link->display_id();
							if( $DB eq 'EMBL' ) {
								my $temp_ID = $ID;
								$temp_ID = $1 if $temp_ID =~ /^([a-z]+\d+\.\d+)/i;
								$zmenu{ "06:$DB: $temp_ID" } = $URL->get_url($DB, $temp_ID);
							} elsif( $DB eq 'SPTREMBL' ) {
								$zmenu{ "07:$DB: $ID" } = $URL->get_url('SWISS-PROT', $ID);
							} else {
								my $temp_ID = $ID;
								$temp_ID = $1 if $temp_ID =~ /^([a-z]+\d+)/i;
								$zmenu{ "08:Protein: $temp_ID" } = 
									$URL->get_url( 'PID', $temp_ID );
							}
                    	}
                    }
					
                    # if we have an EMBL external transcript we need different links...
                    if($tid =~ /dJ/o){
						$zmenu { "05:$tid" } => $URL->get_url('EMBLGENE', $tid);
                    }
                    $zmenu{ "02:Gene: $gene_label"}='' if $gene_label;

                    $Composite->{'zmenu'} = \%zmenu;
                } else {
                    # we have a normal Ensembl transcript...
                    $Composite->{'zmenu'}  = {
                            'caption'            => $id,
                            "00:Transcr:$tid"        => "",
                            "01:(Gene:$vgid)"        => "",
                            '03:Transcript information' => "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$vgid",
                            '04:Protein information'    => "/$ENV{'ENSEMBL_SPECIES'}/protview?peptide=$pid",
                            '05:Supporting evidence'    => "/$ENV{'ENSEMBL_SPECIES'}/transview?transcript=$tid",
                            '06:Expression information' => "/$ENV{'ENSEMBL_SPECIES'}/sageview?alias=$vgid",
                            '07:Protein sequence (FASTA)' => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=peptide&id=$tid",
                            '08:cDNA sequence'          => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=cdna&id=$tid",
                    };
					$Composite->{'zmenu'}->{"02:(Gene:$gene_label)"} if $gene_label;
                    $Composite->{'href'} = "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$vgid";
                }
            } #end of Skip this next chunk if single transcript mode
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
            ########## otherwise we're on the VC and everything's ok
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
                    #'id'        => $exon->stable_id(),
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

            my $bump_height;
            if( $Config->{'_add_labels'} ) {
                my ($font_w_bp, $font_h_bp)   = $Config->texthelper->px2bp($fontname);
                my $tid;
                if( $Config->{'_transcript_names_'} eq 'yes' ) {
                    $tid = $id=~/$PREFIX/o ? 'NOVEL' : $id;
                } else {
                    $tid = $transcript->stable_id();
                }
                my $width_of_label  = $font_w_bp * (length($tid) + 1);
                my $start_of_label  = int( ($start_exon->start() + $end_exon->end() - $width_of_label )/2 );
                $start_of_label  = $start_exon->start();

                my $tglyph = new Bio::EnsEMBL::Glyph::Text({
                    'x'         => $start_of_label,
                    'y'         => $y+$h+2,
                    'height'    => $font_h_bp,
                    'width'     => $width_of_label,
                    'font'      => $fontname,
                    'colour'    => $colour,
                    'text'      => $tid,
                    'absolutey' => 1,
                });
                $Composite->push($tglyph);
                $bump_height = 1.7 * $h + $font_h_bp;
            } else {
                $bump_height = 1.5 * $h;
            }
 
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
            if(!defined $target) {
                if( $superhighlight ) {
                    $Composite->colour( $superhi_colour );
                } elsif( $highlight ) { 
                    $Composite->colour( $hi_colour );
                }
            }
            $self->push($Composite);
        }
    }
}

1;
