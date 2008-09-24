package Bio::EnsEMBL::GlyphSet::genetree_legend;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

sub render_normal {
  my ($self) = @_;

  return unless ($self->strand() == -1);

  my $BOX_WIDTH     = 20;
  my $NO_OF_COLUMNS = 4;

  my $vc            = $self->{'container'};
  my $im_width      = $self->image_width();
  my $type          = $self->my_config('src');
 
  my( $fontname, $fontsize ) = $self->get_font_details( 'legend' );
  my @res = $self->get_text_width( 0, 'X', '', 'font'=>$fontname, 'ptsize' => $fontsize );
  my $th = $res[3];
  my $pix_per_bp = $self->scalex;

  my @branches = (
    ['x1 branch length', 'blue', undef],
    ['x10 branch length', 'blue', 1],
    ['x100 branch length', 'red', 1]
  );
  my @nodes = (
    ['speciation node', 'navyblue'],
    ['duplication node', 'red3'],
    ['ambiguous node', 'turquoise'],
  );
  my @orthos = (
    ['current gene', 'red', 'Gene ID Species A'],
    ['within-sp. paralogue', 'blue', 'Gene ID Species A'],
  );
  my @boxes = (
    ['AA alignment match/mismatch',   'yellowgreen', 'yellowgreen'],
    ['AA alignment (consensus)',      'darkgreen',   'darkgreen'],
    ['AA alignment gap',              'white',       'yellowgreen'],
               );

  my ($legend, $colour, $style, $border, $label, $text);

  $self->push($self->Text({
        'x'         => 0,
        'y'         => 0,
        'height'    => $th,
        'valign'    => 'center',
        'halign'    => 'left',
        'ptsize'    => $fontsize,
        'font'      => $fontname,
        'colour'   =>  'black',
        'text'      => 'LEGEND',
        'absolutey' => 1,
        'absolutex' => 1,
        'absolutewidth'=>1
  }));


  my ($x,$y) = (0, 0);
  foreach my $branch (@branches) {
    ($legend, $colour, $style) = @$branch;
    $self->push($self->Line({
      'x'         => $im_width * $x/$NO_OF_COLUMNS,
      'y'         => $y * ( $th + 3 ) + 8 + $th,
      'width'     => 20,
      'height'    => 0,
      'colour'    => $colour,
      'dotted'    => $style,
      })
    );
    $label = $self->_create_label($im_width, $x, $y, $NO_OF_COLUMNS, $BOX_WIDTH, $th, $fontsize, $fontname, $legend);
    $self->push($label);
    $y++;
  }
  
  ($x, $y) = (1, 0);
  foreach my $ortho (@orthos) {
    ($legend, $colour, $text) = @$ortho;
    $self->push($self->Text({
        'x'         => $im_width * $x/$NO_OF_COLUMNS - 50,
        'y'         => $y * ( $th + 3 ) + $th,
        'height'    => $th,
        'valign'    => 'center',
        'halign'    => 'left',
        'ptsize'    => $fontsize,
        'font'      => $fontname,
        'colour'   =>  $colour,
        'text'      => $text,
        'absolutey' => 1,
        'absolutex' => 1,
        'absolutewidth'=>1

        })
      );
    $label = $self->_create_label($im_width, $x, $y, $NO_OF_COLUMNS, $BOX_WIDTH + 20, $th, $fontsize, $fontname, $legend);
    $self->push($label);
    $y++;
  }

  ($x, $y) = (2, 0);
  foreach my $node (@nodes) {
    ($legend, $colour) = @$node;
    $self->push($self->Rect({
        'x'         => $im_width * $x/$NO_OF_COLUMNS,
        'y'         => $y * ( $th + 3 ) + 5 + $th,
        'width'     => 5,
        'height'    => 5,
        'colour'   => $colour,
        })
      );
    $label = $self->_create_label($im_width, $x, $y, $NO_OF_COLUMNS, $BOX_WIDTH - 20, $th, $fontsize, $fontname, $legend);
    $self->push($label);
    $y++;
  }

  ($x, $y) = (3, 0);
  foreach my $box (@boxes) {
    ($legend, $colour, $border) = @$box;
    $self->push($self->Rect({
        'x'         => $im_width * $x/$NO_OF_COLUMNS,
        'y'         => $y * ( $th + 3 ) + 5 + $th,
        'width'     => 10,
        'height'    => 0,
        'colour'    => $border,
        })
      );
    $self->push($self->Rect({
        'x'         => $im_width * $x/$NO_OF_COLUMNS,
        'y'         => $y * ( $th + 3 ) + 6 + $th,
        'width'     => 10,
        'height'    => 8,
        'colour'    => $colour,
        })
      );
    $self->push($self->Rect({
        'x'         => $im_width * $x/$NO_OF_COLUMNS,
        'y'         => $y * ( $th + 3 ) + 14 + $th,
        'width'     => 10,
        'height'    => 0,
        'colour'    => $border,
        })
      );
    $label = $self->_create_label($im_width, $x, $y, $NO_OF_COLUMNS, $BOX_WIDTH - 10, $th, $fontsize, $fontname, $legend);
    $self->push($label);
    $y++;
  }

}

sub _create_label {
  my ($self,$im_width, $x, $y, $NO_OF_COLUMNS, $BOX_WIDTH, $th, $fontsize, $fontname, $legend) = @_;
  return $self->Text({
      'x'         => $im_width * $x/$NO_OF_COLUMNS + $BOX_WIDTH + 5,
      'y'         => $y * ( $th + 3 ) + $th,
      'height'    => $th,
      'valign'    => 'bottom',
      'halign'    => 'left',
      'ptsize'    => $fontsize,
      'font'      => $fontname,
      'colour'    => 'black',
      'text'      => " $legend",
      'absolutey' => 1,
      'absolutex' => 1,
      'absolutewidth'=>1
    });
}

1;
      
