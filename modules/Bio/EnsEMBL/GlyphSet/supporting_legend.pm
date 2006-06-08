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
#  $self->init_label_text( 'Scores:' );
}

sub _init {
    my ($self) = @_;

    return unless ($self->strand() == 1);

    my $vc            = $self->{'container'};
    my $Config        = $self->{'config'};
    my $im_width      = $Config->image_width();
    my $type          = $Config->get('supporting_legend', 'src');
    
    my $BOX_HEIGHT    = 4;
    my $BOX_WIDTH     = 20;
    my $NO_OF_COLUMNS = 10;
    my $COL_WIDTH     = 60;
    my $FONTNAME      = "Tiny";

    my @colours;
    
    my ($x,$y) = (1,0);


     my $labels = {  
      '100' => $Config->get('supporting_evidence','100'),
      '99' => $Config->get('supporting_evidence','99'),
      '97' => $Config->get('supporting_evidence','97'),
      '90' => $Config->get('supporting_evidence','90'),
      '75' => $Config->get('supporting_evidence','75'),
      '50' => $Config->get('supporting_evidence','50'),
           
      '30' => $Config->get('supporting_evidence','low_score'),
      'No Evidence'		=> $Config->get('supporting_evidence','low_score'),
            	
   };

   $self->push(new Sanger::Graphics::Glyph::Text({
                    'x'          => 1 ,
            	    'y'          => 1,
            	    'font'       => 'Small',
                    'colour'     => 'black',
           	        'text'       => 'Score: ',		            
          	        'absolutey'  => 1,
            	}));

    foreach (sort {$b <=> $a} keys %{$labels}) {
        my $legend = $_;
		$legend = ($legend eq 100) || ($legend eq 'No Evidence') ? $legend : '>='.$legend;
	$legend = '<=30' if ($legend eq '>=30');
	my $colour = %{$labels}->{$_};
            if ($legend eq 'No Evidence'){
	    $self->push(new Sanger::Graphics::Glyph::Rect({
                'x'         => ($x * $COL_WIDTH),
                'y'         => $y * $BOX_HEIGHT * 2 + 6,
                'width'     => $BOX_WIDTH, 
                'height'    => $BOX_HEIGHT,
                'bordercolour'    => $colour,
                'absolutey' => 1,
                'absolutex' => 1,'absolutewidth'=>1,
            }));
	    }else{
	    $self->push(new Sanger::Graphics::Glyph::Rect({
                'x'         => ($x * $COL_WIDTH),
                'y'         => $y * $BOX_HEIGHT * 2 + 6,
                'width'     => $BOX_WIDTH, 
                'height'    => $BOX_HEIGHT,
                'colour'    => $colour,
                'absolutey' => 1,
                'absolutex' => 1,'absolutewidth'=>1,
            }));
	    }
            $self->push(new Sanger::Graphics::Glyph::Text({
                'x'         => ($x * $COL_WIDTH) + $BOX_WIDTH,
                'y'         => $y * $BOX_HEIGHT * 2 + 4,
                'height'    => $Config->texthelper->height($FONTNAME),
                'font'      => $FONTNAME,
                'colour'    => 'black',
                'text'      => uc(" $legend"),
                'absolutey' => 1,
                'absolutex' => 1,'absolutewidth'=>1,
            }));
            $x++;
            if($x==$NO_OF_COLUMNS) {
                $x=0;
                $y++;
            
        }
    }
};

1;
        
