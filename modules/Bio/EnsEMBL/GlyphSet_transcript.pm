package Bio::EnsEMBL::GlyphSet_transcript;
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
        'text'      => $self->my_label(),
        'font'      => 'Small',
        'absolutey' => 1,
    });

    $self->label($label);
}

sub my_label {
    my $self = shift;
    return 'Missing label';
}

sub colours {   return {}; }
sub features {  return []; }

sub _init {
    my ($self) = @_;
    my $type = $self->check();
    return unless defined $type;

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
    my $colours       = $self->colours();

    my $fontname      = "Tiny";    
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($Config->container_width() * $pix_per_bp);
 
    my $vtrans        = $self->features(); 
    my $strand        = $self->strand();

    my $vc_length     = $container->length;    
    my $count = 0;
    
    for my $vt (@$vtrans) {
        # If stranded diagram skip if on wrong strand
        next if $vt->{'strand'}!=$strand;
        # For alternate splicing diagram only draw transcripts in gene
        next if $target_gene && $vt->{'gene'}       ne $target_gene;    
        # For exon_structure diagram only given transcript
        next if $target      && $vt->{'stable_id'} ne $target;         #
        $count=1;        
        my $Composite = new Bio::EnsEMBL::Glyph::Composite({'y'=>$y,'height'=>$h});
        
        $Composite->{'href'}  = $self->href( $vt );
        $Composite->{'zmenu'} = $self->zmenu( $vt ) unless( $Config->{'_href_only'} );
        my($colour, $hilight) = $self->colour( $vt, $colours, %highlights );

        my $flag = 0;
        my @exon_lengths = @{$vt->{'exon_structure'}};
        my $end = $vt->{'start'} - 1;
        my $start = 0;
        my $coding_start = $vt->{'coding_start'} || $vt->{'start'};
        my $coding_end   = $vt->{'coding_end'}   || $vt->{'end'};
        foreach my $length (@exon_lengths) {
            $flag = 1-$flag;
            ($start,$end) = ($end+1,$end+$length);
            last if $start > $container->{'length'};
            next if $end< 0;
            my $box_start = $start < 1 ?       1 :       $start;
            my $box_end   = $end   > $vc_length ? $vc_length : $end;
            if($flag == 1) { ## draw an exon ##
                if($box_start < $coding_start || $box_end > $coding_end ) {
                    my $rect = new Bio::EnsEMBL::Glyph::Rect({
                        'x'         => $box_start,
                        'y'         => $y+1,
                        'width'     => $box_end-$box_start,
                        'height'    => $h-2,
                        'bordercolour' => $colour,
                        'absolutey' => 1,
                    });
                    $Composite->push($rect);
                    my $START = $box_start < $coding_start ? $coding_start : $box_start;
                    my $END   = $box_end   < $coding_end   ? $box_end      : $coding_end;
                    $rect = new Bio::EnsEMBL::Glyph::Rect({
                        'x'         => $START,
                        'y'         => $y,
                        'width'     => $END - $START,
                        'height'    => $h,
                        'colour'    => $colour,
                        'absolutey' => 1,
                    });
                    $Composite->push($rect);
                } else {
                    my $rect = new Bio::EnsEMBL::Glyph::Rect({
                        'x'         => $box_start,
                        'y'         => $y,
                        'width'     => $box_end-$box_start,
                        'height'    => $h,
                        'colour'    => $colour,
                        'absolutey' => 1,
                    });
                    $Composite->push($rect);
                }
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
                
        my $bump_height = 1.5 * $h;
        if( $Config->{'_add_labels'} ) {
            if(my $text_label = $self->text_label($vt) ) {
                my ($font_w_bp, $font_h_bp)   = $Config->texthelper->px2bp($fontname);
                my $width_of_label  = $font_w_bp * 1.15 * (length($text_label) + 1);
                my $tglyph = new Bio::EnsEMBL::Glyph::Text({
                    'x'         => $Composite->x(),
                    'y'         => $y+$h+2,
                    'height'    => $font_h_bp,
                    'width'     => $width_of_label,
                    'font'      => $fontname,
                    'colour'    => $colour,
                    'text'      => $text_label,
                    'absolutey' => 1,
                });
                $Composite->push($tglyph);
                $bump_height = 1.7 * $h + $font_h_bp;
            }
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
        $Composite->colour( $hilight ) if(defined $hilight && !defined $target);
        $self->push($Composite);
        
        if($target) {        
            if($vt->{'strand'} == 1) {
                my $clip1 = new Bio::EnsEMBL::Glyph::Line({
                   'x'         => 1,
                   'y'         => -4,
                   'width'     => $vc_length,
                   'height'    => 0,
                   'absolutey' => 1,
                   'colour'    => $colour
                });
                $self->push($clip1);
                $clip1 = new Bio::EnsEMBL::Glyph::Poly({
                	'points'    => [$vc_length - 4/$pix_per_bp,-2,
                                    $vc_length                ,-4,
                                    $vc_length - 4/$pix_per_bp,-6],
    	            'colour'    => $colour,
                	'absolutey' => 1,
                });
                $self->push($clip1);
            } else {
                my $clip1 = new Bio::EnsEMBL::Glyph::Line({
                   'x'         => 1,
                   'y'         => $h+4,
                   'width'     => $vc_length,
                   'height'    => 0,
                   'absolutey' => 1,
                   'colour'    => $colour
                });
                $self->push($clip1);
                $clip1 = new Bio::EnsEMBL::Glyph::Poly({
                	'points'    => [1+4/$pix_per_bp,$h+6,
                                    1,              $h+4,
                                    1+4/$pix_per_bp,$h+2],
    	            'colour'    => $colour,
                	'absolutey' => 1,
                });
                $self->push($clip1);
            }
        }
    }

    if($count) {
        my ($key, $priority, $legend) = $self->legend( $colours );
        $Config->{'legend_features'}->{$key} = {
            'priority' => $priority,
            'legend'   => $legend
        } if defined($key);

    } elsif( $Config->get('_settings','opt_empty_tracks')!=0) {
        $self->errorTrack( "No ".$self->error_track_name()." in this region" );
    }
}

1;
