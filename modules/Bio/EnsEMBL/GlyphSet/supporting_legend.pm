package Bio::EnsEMBL::GlyphSet::supporting_legend;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use  Sanger::Graphics::Bump;

sub init_label {
    my ($self) = @_;
    return if( defined $self->{'config'}->{'_no_label'} );
    my $label = new Sanger::Graphics::Glyph::Text({
        'text'      => 'Scores: ',
        'font'      => 'Small',
        'absolutey' => 1,
    });
#    $self->label($label);
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == 1);

    my $BOX_HEIGHT    = 4;
    my $BOX_WIDTH     = 20;
    my $NO_OF_COLUMNS = 2;
    my $FONTNAME      = "Tiny";

    my $vc            = $self->{'container'};
    my $Config        = $self->{'config'};
    my $im_width      = $Config->image_width();
    my $type          = $Config->get('supporting_legend', 'src');

    my @colours;
    
    my ($x,$y) = (0,0);


     my $labels = {  
      'Score 100' => $Config->get('supporting_evidence','100'),
      'Score 90' => $Config->get('supporting_evidence','90'),
      'Low scoring evidence' => $Config->get('supporting_evidence','low_score'),
      'No Evidence'		=> $Config->get('supporting_evidence','low_score'),	
   };

    foreach (sort keys %{$labels}) {
        $y++ unless $x==0;
        $x=0;
        my $legend = $_ ;
	my $colour = %{$labels}->{$_};
            if ($legend eq 'No Evidence'){
	    $self->push(new Sanger::Graphics::Glyph::Rect({
                'x'         => $im_width * $x/$NO_OF_COLUMNS,
                'y'         => $y * $BOX_HEIGHT * 2 + 6,
                'width'     => $BOX_WIDTH, 
                'height'    => $BOX_HEIGHT,
                'bordercolour'    => $colour,
                'absolutey' => 1,
                'absolutex' => 1,
            }));
	    }else{
	    $self->push(new Sanger::Graphics::Glyph::Rect({
                'x'         => $im_width * $x/$NO_OF_COLUMNS,
                'y'         => $y * $BOX_HEIGHT * 2 + 6,
                'width'     => $BOX_WIDTH, 
                'height'    => $BOX_HEIGHT,
                'colour'    => $colour,
                'absolutey' => 1,
                'absolutex' => 1,
            }));
	    }
            $self->push(new Sanger::Graphics::Glyph::Text({
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
};

1;
        
