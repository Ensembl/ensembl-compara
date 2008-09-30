package Bio::EnsEMBL::GlyphSet::fg_regulatory_features_legend;

use strict;
use Bio::EnsEMBL::GlyphSet;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end);
our @ISA = qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my ($self) = @_;
  return unless ($self->strand() == -1);

  my $BOX_WIDTH     = 20;
  my $NO_OF_COLUMNS = 2;

  my $vc            = $self->{'container'};
  my $Config        = $self->{'config'};
  my $im_width      = $Config->image_width();
 # my $type          = $Config->get_parameter('fg_regulatory_features_legend', 'src');
   
  my @colours;
  return unless $Config->{'fg_regulatory_features_legend_features'};
  my %features = %{$Config->{'fg_regulatory_features_legend_features'}}; 
  return unless %features;

 
  my ($x,$y) = (0,0);
  my( $fontname, $fontsize ) = $self->get_font_details( 'legend' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $th = $res[3];
  my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};
  
  my $FLAG = 0;
  foreach (sort { $features{$b}->{'priority'} <=> $features{$a}->{'priority'} } keys %features) {                                              
    @colours = @{$features{$_}->{'legend'}}; 

    $y++ unless $x==0;
    $x=0;
    while( my ($legend, $colour) = splice @colours, 0, 2 ) {
      $FLAG = 1;
      my $tocolour='';
      ($tocolour,$colour) = ($1,$2) if $colour =~ /(.*):(.*)/;
      $self->push($self->Rect({
        'x'         => $im_width * $x/$NO_OF_COLUMNS,
        'y'         => $y * ( $th + 3 ) + 2,
        'width'     => $BOX_WIDTH,
        'height'    => $th-2,
        $tocolour.'colour'    => $colour,
        'absolutey' => 1,
        'absolutex' => 1,'absolutewidth'=>1,
      }));
      $self->push($self->Text({
        'x'         => $im_width * $x/$NO_OF_COLUMNS + $BOX_WIDTH,
        'y'         => $y * ( $th + 3 ),
        'height'    => $th,
        'valign'    => 'center',
        'halign'    => 'left',
        'ptsize'    => $fontsize,
        'font'      => $fontname,
        'colour'    => 'black',
        'text'      => " $legend",
        'absolutey' => 1,
        'absolutex' => 1,'absolutewidth'=>1
      }));
      $x++;
      if($x==$NO_OF_COLUMNS) {
        $x=0;
        $y++;
      }
    }
  }
# Set up a separating line...
  my $rect = $self->Rect({
    'x'         => 0,
    'y'         => 0,
    'width'     => $im_width,
    'height'    => 0,
    'colour'    => 'grey50',
    'absolutey' => 1,
    'absolutex' => 1,'absolutewidth'=>1,
  });
  $self->push($rect);
  unless( $FLAG ) {
    $self->errorTrack( "No Regulatory Features in this panel" );
  }
}

1;
