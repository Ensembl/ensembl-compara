package Bio::EnsEMBL::GlyphSet::sanger_transcript_lite;
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
    
    my $label_text = $self->{'config'}->{'_draw_single_Transcript'} || "Sanger Trans.";

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

    my $sanger_colours = {
        'hi'               => $Config->get('sanger_transcript_lite','hi'),
        'super'            => $Config->get('sanger_transcript_lite','superhi'),
        'Novel_CDS'        => $Config->get('sanger_transcript_lite','sanger_Novel_CDS'),
        'Putative'         => $Config->get('sanger_transcript_lite','sanger_Putative'),
        'Known'            => $Config->get('sanger_transcript_lite','sanger_Known'),
        'Novel_Transcript' => $Config->get('sanger_transcript_lite','sanger_Novel_Transcript'),
        'Pseudogene'       => $Config->get('sanger_transcript_lite','sanger_Pseudogene'),
    };


    my $fontname      = "Tiny";    
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($Config->container_width() * $pix_per_bp);
    my $URL = ExtURL->new();
 
    my $colour;

    my $vtrans_sanger = $container->get_all_VirtualTranscripts_startend_lite( 'sanger' );
    my $strand = $self->strand();

    my $vc_length     = $container->length;    
    my $count = 0;
    
    for my $vt (@$vtrans_sanger) {
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
        my $T = $vt->{'type'};
        $T =~ s/HUMACE-//g;
        $colour = $sanger_colours->{$T};
    
        unless( $target ) {     #Skip this next chunk if single transcript mode
            if( $Config->{'_href_only'} eq '#tid' ) {
                $Composite->{'href'} = qq(#$vtid);
            } else {
	            $Composite->{'href'} = qq(/$ENV{'ENSEMBL_SPECIES'}/geneview?db=sanger&gene=$vgid);
			    my %zmenu = (
                    'caption'           => "Sanger Gene",
				    "01:$vtid"          => '',
				    "03:Sanger curated ($T)" => ''
			    );
                # if we have an EMBL external transcript we need different links...
                $zmenu{ "02:Gene: $vgid"}=$Composite->{'href'};
                $Composite->{'zmenu'} = \%zmenu;
            }
        } #end of Skip this next chunk if single transcript mode

        my $flag = 0;
        my @exon_lengths = @{$vt->{'exon_structure'}};
        my $end = $vt->{'start'} - 1;
        my $start = 0;
#        print STDERR "TRANSCRIPT: $vtid, $vt->{'start'}-$vt->{'end'}\n          : ",join(' : ',@exon_lengths),"\n";
        foreach my $length (@exon_lengths) {
            $flag = 1-$flag;
            ($start,$end) = ($end+1,$end+$length);
#            print STDERR "transcript_lite-- EXON: $start - $end\n";
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
                $Composite->colour( $sanger_colours->{'superhi'} );
            } elsif( $highlight_gene ) { 
                $Composite->colour( $sanger_colours->{'hi'} );
            }
        }
        $self->push($Composite);
    }

    if(@$vtrans_sanger) {
        $Config->{'legend_features'}->{'sanger_genes'} = {
            'priority' => 1000,
            'legend'  => [
                'Sanger curated known genes'    => $sanger_colours->{'Known'},
                'Sanger curated novel CDS'      => $sanger_colours->{'Novel_CDS'},
                'Sanger curated putative'       => $sanger_colours->{'Putative'},
                'Sanger curated novel Trans'    => $sanger_colours->{'Novel_Transcript'},
                'Sanger curated pseudogenes'    => $sanger_colours->{'Pseudogene'}
            ]
        };
    } elsif( $Config->get('_settings','opt_empty_tracks')!=0 ) {
        $self->errorTrack( "No Sanger transcripts in this region" );
    }

}

1;
