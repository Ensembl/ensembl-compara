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
    
    my $BOX_WIDTH     = 20;
    my $NO_OF_COLUMNS = 10;
    my $COL_WIDTH     = 60;
  my( $fontname_i, $fontsize_i ) = $self->get_font_details( 'innertext' );
  my @res_i = $self->get_text_width( 0, 'X', '', 'font'=>$fontname_i, 'ptsize' => $fontsize_i );
  my $th_i = $res_i[3];
  my( $fontname_o, $fontsize_o ) = $self->get_font_details( 'label' );
  my @res_o = $self->get_text_width( 0, 'X', '', 'font'=>$fontname_o, 'ptsize' => $fontsize_o );
  my $th_o = $res_o[3];
    my $BOX_HEIGHT    = $th_i;

    my @colours;
    
    my ($x,$y) = (1,0);


     my $labels = {  
      '100' => $Config->get('supporting_evidence','100'),
      '99'  => $Config->get('supporting_evidence','99'),
      '97'  => $Config->get('supporting_evidence','97'),
      '90'  => $Config->get('supporting_evidence','90'),
      '75'  => $Config->get('supporting_evidence','75'),
      '50'  => $Config->get('supporting_evidence','50'),
           
      '30'  => $Config->get('supporting_evidence','low_score'),
      'No Evidence'        => $Config->get('supporting_evidence','low_score'),
                
   };

   $self->push(new Sanger::Graphics::Glyph::Text({
     'x'          => 1 ,
     'y'          => -1,
     'height'     => $th_o,
     'font'       => $fontname_o,
     'ptsize'     => $fontsize_o,
     'halign'     => 'left',
     'colour'     => 'black',
     'text'       => 'Score: ',                    
     'absolutey'  => 1,
     'absolutex'  => 1,
     'absolutewidth'  => 1,
   }));

  foreach (sort {$b <=> $a} keys %{$labels}) {
    my $legend = $_;
    $legend = ($legend eq 100) || ($legend eq 'No Evidence') ? $legend : '>='.$legend;
    $legend = '<=50' if ($legend eq '>=30');
    my $colour = %{$labels}->{$_};
    $self->push(new Sanger::Graphics::Glyph::Rect({
      'x'         => ($x * $COL_WIDTH),
      'y'         => $y * $BOX_HEIGHT * 2 + ($th_o-$th_i)/2,
      'width'     => $BOX_WIDTH, 
      'height'    => $BOX_HEIGHT,
      ($legend eq 'No Evidence'?'border':'').'colour'    => $colour,
      'absolutey' => 1,
      'absolutex' => 1,'absolutewidth'=>1,
    }));
    $self->push(new Sanger::Graphics::Glyph::Text({
      'x'         => ($x * $COL_WIDTH) + $BOX_WIDTH,
      'y'         => $y * $BOX_HEIGHT * 2 + ( $th_o-$th_i)/2 - 1,
      'font'      => $fontname_i,
      'ptsize'    => $fontsize_i,
      'height'     => $th_i,
      'halign'    => 'left',
      'colour'    => 'black',
      'text'      => uc(" $legend"),
      'absolutey' => 1,
      'absolutex' => 1,
      'absolutewidth'=>1,
    }));
    $x++;
    if($x==$NO_OF_COLUMNS) {
      $x=0;
      $y++;
    }
  }
};

1;
        
