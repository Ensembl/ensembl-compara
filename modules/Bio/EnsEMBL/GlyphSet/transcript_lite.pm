package Bio::EnsEMBL::GlyphSet::transcript_lite;
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
    
    my $label_text = $self->{'config'}->{'_draw_single_Transcript'} || 'Transcript(l)';

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
    my %colours = (
        'novel'     => $Config->get('transcript','unknown'),
        'known'     => $Config->get('transcript','known'),
        'pseudo'    => $Config->get('transcript','pseudo'),
        'ext'       => $Config->get('transcript','ext'),
        'hi'        => $Config->get('transcript','hi'),
        'superhi'   => $Config->get('transcript','superhi')
    );

    my $fontname      = "Tiny";    
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($Config->container_width() * $pix_per_bp);
    my $URL = ExtURL->new();
 
    my $colour;

    my $all_vtrans = $container->get_all_VirtualTranscripts_startend_lite();
    my $strand = $self->strand();

    my $vc_length     = $container->length;    
    my $count = 0;
    for my $vt (@$all_vtrans) {
        # If stranded diagram skip if on wrong strand
        next if $vt->{'strand'}!=$strand;
        # For alternate splicing diagram only draw transcripts in gene
        next if $target_gene && $vt->{'gene'}       ne $target_gene;    
        # For exon_structure diagram only given transcript
        next if $target      && $vt->{'transcript'} ne $target;         #
        
        my $vgid = $vt->{'gene'};
        my $vtid = $vt->{'stable_id'};
        my $id   = $vt->{'synonym'} eq '' ? $vtid : $vt->{'synonym'};
        my $highlight_gene =  exists $highlights{$vgid} ? 1 : 0;
        my $superhighlight = (exists $highlights{$vtid} || exists $highlights{$id} ) ? 1 : 0;

        my $Composite = new Bio::EnsEMBL::Glyph::Composite({'y'=>$y,'height'=>$h});
        $colour = $colours{$vt->{'type'}};
        
        if( $Config->{'_href_only'} && $vt->{'type'} ne 'novel' && $vt->{'type'} ne 'known' ) {
            $Composite->{'href'} = qq(/$ENV{'ENSMEBL_SPECIES'}/geneview?gene=$vgid);
        } elsif ($vt->{'type'} ne 'novel' && $vt->{'type'} ne 'known') {
            $Composite->{'zmenu'}  = {
                'caption'  => "EMBL: ".$vt->{'external_name'},
                '01:EMBL curated '.($vt->{'type'} eq 'pseudo' ? 'pseudogene' : 'transcript') => '',
                '03:Sort out external links' => ''
            };
        } else {
            # we have a normal Ensembl transcript...
            $Composite->{'zmenu'}  = {
                'caption'            => $id,
                "00:Transcr:$vtid"   => "",
                "01:(Gene:$vgid)"    => "",
                '03:Transcript information' => "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$vgid",
                '04:Protein information'    => "/$ENV{'ENSEMBL_SPECIES'}/protview?peptide=".$vt->{'translation'},
                '05:Supporting evidence'    => "/$ENV{'ENSEMBL_SPECIES'}/transview?transcript=$vtid",
                '06:Expression information' => "/$ENV{'ENSEMBL_SPECIES'}/sageview?alias=$vgid",
                '07:Protein sequence (FASTA)' => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=peptide&id=$vtid",
                '08:cDNA sequence'          => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=cdna&id=$vtid",
            };
            $Composite->{'href'} = "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$vgid";
        }

        my $flag = 0;
        my @exon_lengths = @{$vt->{'exon_structure'}};
        my $end = $vt->{'start'} - 1;
        my $start = 0;
        print STDERR "TRANSCRIPT: $vtid, $vt->{'start'}-$vt->{'end'}\n          : ",join(' : ',@exon_lengths),"\n";
        foreach my $length (@exon_lengths) {
            $flag = 1-$flag;
            ($start,$end) = ($end+1,$end+$length);
            print STDERR "transcript_lite-- EXON: $start - $end\n";
            last if $start > $container->{'length'};
            next if $end< 0;
            my $box_start = $start < 1 ?       1 :       $start;
            my $box_end   = $end   > $vc_length ? $vc_length : $end;
            if($flag == 1) { ## draw an exon ##
                my $rect = new Bio::EnsEMBL::Glyph::Rect({
                    'x'         => $box_start,
                    'y'         => $y,
                    'width'     => $box_end-$box_start,
                    'height'    => $h,
                    'colour'    => $colour,
                    'absolutey' => 1,
                });
                $Composite->push($rect);
            ## else draw an wholly in vc intron ##
            } elsif( $box_start == $start && $box_end == $end ) { 
                my $intron = new Bio::EnsEMBL::Glyph::Intron({
                    'x'         => $box_start,
                    'y'         => $y,
                    'width'     => $box_end-$box_start,
                    'height'    => $h,
                    'colour'    => $colour,
                    'absolutey' => 1,
                    'strand'    => $strand,
                });
                $Composite->push($intron);
            ## else draw a "not in vc" intron ##
            } else { 
                 my $clip1 = new Bio::EnsEMBL::Glyph::Line({
                     'x'         => $box_start,
                     'y'         => $y+int($h/2),
                     'width'     => $box_end-$box_start,
                     'height'    => 0,
                     'absolutey' => 1,
                     'colour'    => $colour,
                     'dotted'    => 1,
                 });
                 $Composite->push($clip1);
            }
        }
        
        my $bump_height;
        if( $Config->{'_add_labels'} ) {
            my ($font_w_bp, $font_h_bp)   = $Config->texthelper->px2bp($fontname);
            my $tid = $Config->{'_transcript_names_'} eq 'yes' ? ($vt->{'type'} eq 'novel'?'NOVEL':$id) : $vtid;
            my $width_of_label  = $font_w_bp * (length($tid) + 1);

            my $tglyph = new Bio::EnsEMBL::Glyph::Text({
                'x'         => $Composite->x(),
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
 
        ########## bump it baby, yeah! bump-nology!
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
    
        ########## shift the composite container by however much we're bumped
        $Composite->y($Composite->y() - $strand * $bump_height * $row);
        if(!defined $target) {
            if( $superhighlight ) {
                $Composite->colour( $colours{'superhi'} );
            } elsif( $highlight_gene ) { 
                $Composite->colour( $colours{'hi'} );
            }
        }
        $self->push($Composite);
    }
}

1;
