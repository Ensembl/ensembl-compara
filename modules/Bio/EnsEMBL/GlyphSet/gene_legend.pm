package Bio::EnsEMBL::GlyphSet::gene_legend;

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

  my @colours;
  return unless $Config->{'legend_features'};
  my %features = %{$Config->{'legend_features'}};
  return unless %features;

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
    
  my ($x,$y) = (0,0);
  my( $fontname, $fontsize ) = $self->get_font_details( 'legend' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $th = $res[3];
  my $pix_per_bp = $self->{'config'}->transform()->{'scalex'};

  my %seen;
  foreach (sort { $features{$a}->{'priority'} <=> $features{$b}->{'priority'} } keys %features) {
    @colours = @{$features{$_}->{'legend'}};
    $y++ unless $x==0;
    $x=0;
    while( my ($legend, $colour) = splice @colours, 0, 2 ) {
		next if $seen{"$legend:$colour"};
		$seen{"$legend:$colour"} = 1;
      $self->push($self->Rect({
        'x'         => $im_width * $x/$NO_OF_COLUMNS,
        'y'         => $y * ( $th + 3 ) + 2,
        'width'     => $BOX_WIDTH, 
        'height'    => $th-2,
        'colour'    => $colour,
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
        'absolutex' => 1,'absolutewidth'=>1,
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
        
