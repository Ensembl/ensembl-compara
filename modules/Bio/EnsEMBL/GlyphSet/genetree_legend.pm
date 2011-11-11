package Bio::EnsEMBL::GlyphSet::genetree_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub render_normal {
  my ($self) = @_;

  return unless ($self->strand() == -1);

  my $BOX_WIDTH     = 20;
  my $NO_OF_COLUMNS = 5;

  my $vc            = $self->{'container'};
  my $im_width      = $self->image_width();
  my $type          = $self->my_config('src');
  my $other_gene            = $self->{highlights}->[5];
  my $highlight_ancestor    = $self->{highlights}->[6];

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
    ['gene split event', 'SandyBrown', 'border'],
  );
  if ($highlight_ancestor) {
    push(@nodes, ['ancestor node', '444444', "bold"]);
  }
  my @orthos = (
    ['current gene', 'red', 'Gene ID'],
    ['within-sp. paralog', 'blue', 'Gene ID'],
  );
  if ($other_gene) {
    @orthos = (
      ['current gene', 'red', 'Gene ID', 'white'],
      ['within-sp. paralog', 'blue', 'Gene ID', 'white'],
      ['other gene', 'black', 'Gene ID', 'ff6666'],
      ['other within-sp. paralog', 'black', 'Gene ID', 'white'],
    );
  }
  my @polys = (
    ['collapsed sub-tree', 'grey'], 
    ['collapsed (current gene)', 'red' ],
    ['collapsed (paralog)', 'royalblue'],
  );
  
  my $alphabet = "AA";
  if (UNIVERSAL::isa($vc, "Bio::EnsEMBL::Compara::NCTree")) {
    $alphabet = "Nucl.";
  }
  my @boxes = (
    ["$alphabet alignment match/mismatch",   'yellowgreen', 'yellowgreen'],
    ["$alphabet consensus > 66% (mis)match",      'darkgreen',   'darkgreen'],
    ["$alphabet consensus > 33% (mis)match",      'yellowgreen',   'darkgreen'],
    ["$alphabet alignment gap",              'white',       'yellowgreen'],
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
    my $bold_colour;
    ($legend, $colour, $text, $bold_colour) = @$ortho;
    my $txt = $self->Text({
        'x'         => $im_width * $x/$NO_OF_COLUMNS - 0,
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

        });
    if ($bold_colour) {
      for (my $delta_x = -1; $delta_x <= 1; $delta_x++) {
        for (my $delta_y = -1; $delta_y <= 1; $delta_y++) {
          next if ($delta_x == 0 and $delta_y == 0);
          my %txt2 = %$txt;
          bless(\%txt2, ref($txt));
          $txt2{x} += $delta_x;
          $txt2{y} += $delta_y;
          $self->push(\%txt2);
        }
      }
      $txt->{colour} = $bold_colour;
    }
    $self->push($txt);
    $label = $self->_create_label($im_width, $x, $y, $NO_OF_COLUMNS, $BOX_WIDTH + 20, $th, $fontsize, $fontname, $legend);
    $self->push($label);
    $y++;
  }

  ($x, $y) = (2, 0);
  foreach my $node (@nodes) {
    my $modifier;
    ($legend, $colour, $modifier) = @$node;
    my $bold = (defined $modifier and ($modifier eq 'bold'));
    $self->push($self->Rect({
        'x'         => $im_width * $x/$NO_OF_COLUMNS - $bold,
        'y'         => $y * ( $th + 3 ) + $th - $bold,
        'width'     => 5 + 2 * $bold,
        'height'    => 5 + 2 * $bold,
        'colour'    => $colour,
        })
      );
    if ($bold) {
      $self->push($self->Rect({
            'x'         => $im_width * $x/$NO_OF_COLUMNS,
            'y'         => $y * ( $th + 3 ) + $th,
            'width'     => 5,
            'height'    => 5,
            'bordercolour' => "white",
          })
        );
    }
    if (defined $modifier and ($modifier eq 'border')) {
      $self->push($self->Rect({
            'x'         => $im_width * $x/$NO_OF_COLUMNS - $bold,
            'y'         => $y * ( $th + 3 ) + $th - $bold,
            'width'     => 5 + 2 * $bold,
            'height'    => 5 + 2 * $bold,
            'bordercolour' => 'navyblue',
          })
        );
    }
    $label = $self->_create_label($im_width, $x, $y - 4 / ($th+3), $NO_OF_COLUMNS, $BOX_WIDTH - 20, $th, $fontsize, $fontname, $legend);
    $self->push($label);
    $y++;
  }

  ($x, $y) = (3, 0);
  foreach my $poly (@polys) {
    ($legend, $colour) = @$poly;
    my $px = $im_width * $x/$NO_OF_COLUMNS;
    my $py = $y * ( $th + 3 ) + 8 + $th;
    my($width,$height) = (12,12);
    $self->push($self->Poly({
      'points' => [ $px, $py,
                    $px + $width, $py - ($height / 2 ),
                    $px + $width, $py + ($height / 2 ) ],
      'colour'   => $colour,
    }) );
    $label = $self->_create_label
        ($im_width, $x, $y, $NO_OF_COLUMNS, $BOX_WIDTH - 8, $th, 
         $fontsize, $fontname, $legend);
    $self->push($label);
    $y++;
  }

  ($x, $y) = (4, 0);
  foreach my $box (@boxes) {
    ($legend, $colour, $border) = @$box;
    $self->push($self->Rect({
        'x'         => $im_width * $x/$NO_OF_COLUMNS,
        'y'         => $y * ( $th + 3 ) + 1 + $th,
        'width'     => 10,
        'height'    => 0,
        'colour'    => $border,
        })
      );
    $self->push($self->Rect({
        'x'         => $im_width * $x/$NO_OF_COLUMNS,
        'y'         => $y * ( $th + 3 ) + 2 + $th,
        'width'     => 10,
        'height'    => 8,
        'colour'    => $colour,
        })
      );
    $self->push($self->Rect({
        'x'         => $im_width * $x/$NO_OF_COLUMNS,
        'y'         => $y * ( $th + 3 ) + 10 + $th,
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
      
