package Bio::EnsEMBL::GlyphSet::genscan_lite;
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
    
    my $label = new Bio::EnsEMBL::Glyph::Text({
        'text'      => 'Genscan(l)',
        'font'      => 'Small',
        'absolutey' => 1,
    });

    $self->label($label);
}

sub _init {
    my ($self) = @_;
    my $Config        = $self->{'config'};
    my $container     = $self->{'container'};
    
    my $y             = 0;
    my $h             = 8;   #Single transcript mode - set height to 30 - width to 8!
    
    my $vcid          = $container->id();
    my %highlights;
    @highlights{$self->highlights} = ();    # build hashkeys of highlight list

    my @bitmap        = undef;
    my $im_width      = $Config->image_width();
    my $colour        = $Config->get('genscan_lite', 'col');

    my $fontname      = "Tiny";    
    my $pix_per_bp    = $Config->transform->{'scalex'};
    my $bitmap_length = int($Config->container_width() * $pix_per_bp);
    my $URL = ExtURL->new();
 
    my $all_vtrans = $container->get_all_VirtualGenscans_startend_lite();
    my $strand     = $self->strand();

    my $vc_length     = $container->length;    
    my $count = 0;
    for my $vt (@$all_vtrans) {
        # If stranded diagram skip if on wrong strand
        next if $vt->{'strand'}!=$strand;
        
        my $Composite = new Bio::EnsEMBL::Glyph::Composite({'y'=>$y,'height'=>$h});
        
        my $flag = 0;
        my @exon_lengths = @{$vt->{'exon_structure'}};
        my $end = $vt->{'start'} - 1;
        my $start = 0;
        foreach my $length (@exon_lengths) {
            $flag = 1-$flag;
            ($start,$end) = ($end+1,$end+$length);
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
        
        my $bump_height = 1.5 * $h;

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
        $self->push($Composite);
    }
}

1;
