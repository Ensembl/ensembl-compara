package Bio::EnsEMBL::GlyphSet::gene_legend;
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
        'text'      => 'Gene legend',
        'font'      => 'Small',
        'absolutey' => 1,
    });
    $self->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == -1);

    my $BOX_HEIGHT    = 4;
    my $BOX_WIDTH     = 20;
    my $NO_OF_COLUMNS = 3;
    my $FONTNAME      = "Tiny";

    my $vc            = $self->{'container'};
    my $Config        = $self->{'config'};
    my $im_width      = $Config->image_width();
    my $type          = $Config->get('gene_legend', 'src');

    my @colours;
    return unless $Config->{'legend_features'};
    my %features = %{$Config->{'legend_features'}};
    return unless %features;

    my ($x,$y) = (0,0);
    my $rect = new Bio::EnsEMBL::Glyph::Rect({
       'x'         => 0,
       'y'         => 0,
       'width'     => $im_width, 
       'height'    => 0,
       'colour'    => $Config->colourmap->id_by_name('grey3'),
       'absolutey' => 1,
       'absolutex' => 1,
    });
    $self->push($rect);
    
    foreach (sort { $features{$b}->{'priority'} <=> $features{$a}->{'priority'} } keys %features) {
        @colours = @{$features{$_}->{'legend'}};
        $y++ unless $x==0;
        $x=0;
        while( my ($legend, $colour) = splice @colours, 0, 2 ) {
            $self->push(new Bio::EnsEMBL::Glyph::Rect({
                'x'         => $im_width * $x/$NO_OF_COLUMNS,
                'y'         => $y * $BOX_HEIGHT * 2 + 6,
                'width'     => $BOX_WIDTH, 
                'height'    => $BOX_HEIGHT,
                'colour'    => $colour,
                'absolutey' => 1,
                'absolutex' => 1,
            }));
            $self->push(new Bio::EnsEMBL::Glyph::Text({
                'x'         => $im_width * $x/$NO_OF_COLUMNS + $BOX_WIDTH,
                'y'         => $y * $BOX_HEIGHT * 2 + 4,
                'height'    => $Config->texthelper->height($FONTNAME),
                'font'      => $FONTNAME,
                'colour'    => $colour,
                'text'      => uc(" $legend"),
                'absolutey' => 1,
                'absolutex' => 1,
            }));
            $x++;
            if($x==$NO_OF_COLUMNS) {
                $x=0;
                $y++;
            }
        }
    }
}

1;
        
