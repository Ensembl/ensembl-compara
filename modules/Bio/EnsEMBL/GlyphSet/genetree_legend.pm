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

  my @branches = $vc->isa('Bio::EnsEMBL::Compara::CAFEGeneFamily') ? (['N number of members', 'blue', undef],['Expansion', '#800000', undef],['Contraction', '#008000', undef],['No significant change', 'blue', undef]) :(
    ['Branch Length','header'],
    ['x1 branch length', 'blue', undef],
    ['x10 branch length', 'blue', 1],
    ['x100 branch length', 'red', 1]
  );
  my @nodes = $vc->isa('Bio::EnsEMBL::Compara::CAFEGeneFamily') ?  (
    ['Nodes with 0 members ', 'grey'],
    ['Nodes with 1-5 members', '#FEE391'],
    ['Nodes with 6-10 members', '#FEC44F'],
    ['Nodes with 11-15 members', '#FE9929'],
    ['Nodes with 16-20 members', '#EC7014'],
    ['Nodes with 21-25 members', '#CC4C02'],
    ['Nodes with >25 members', '#8C2D04'],
  ): (
    ['Nodes','header'],
    ['gene node', 'white', 'border'],
    ['speciation node', 'navyblue'],
    ['duplication node', 'red3'],
    ['ambiguous node', 'turquoise'],
    ['gene split event', 'SandyBrown', 'border'],
  );
  if ($highlight_ancestor) {
    push(@nodes, ['ancestor node', '444444', "bold"]);
  }
  my @orthos = $vc->isa('Bio::EnsEMBL::Compara::CAFEGeneFamily') ? ( ["Species of interest", 'red', 'Species'], ["Species with no genes", 'grey', 'Species'] ):(
    ['Genes','header'],
    ['gene of interest', 'red', 'Gene ID'],
    ['within-sp. paralog', 'blue', 'Gene ID'],
  );
  if ($other_gene) {
    @orthos = (
      ['Genes','header'],
      ['gene of interest', 'red', 'Gene ID', 'white'],
      ['within-sp. paralog', 'blue', 'Gene ID', 'white'],
      ['other gene', 'black', 'Gene ID', 'ff6666'],
      ['other within-sp. paralog', 'black', 'Gene ID', 'white'],
    );
  }
  
  my $alphabet = "AA";
  if (UNIVERSAL::isa($vc, "Bio::EnsEMBL::Compara::NCTree")) {
    $alphabet = "Nucl.";
  }  
  
  my @polys = $vc->isa('Bio::EnsEMBL::Compara::CAFEGeneFamily') ? [] :(
    ['Collapsed Nodes','header'],
    ['collapsed sub-tree', 'grey'], 
    ['collapsed (gene of interest)', 'red' ],
    ['collapsed (paralog)', 'royalblue'],    
  );
  
  my @collapsed_boxes = $vc->isa('Bio::EnsEMBL::Compara::CAFEGeneFamily') ? [] : (
    ['Collapsed Alignments','header'],
    ["0 - 33% Aligned $alphabet",'white', 'darkgreen'],
    ["33 - 66% Aligned $alphabet",'yellowgreen', 'darkgreen'],
    ["66 - 100% Aligned $alphabet",'darkgreen','darkgreen'],
  );
  
  #no alignments legend required for cafetree/speciestree
  my @boxes = $vc->isa('Bio::EnsEMBL::Compara::CAFEGeneFamily') ? [] : (
    ['Expanded Alignments','header'],
    ["Gap",   'white', 'yellowgreen'],
    ["Aligned $alphabet", 'yellowgreen',   'yellowgreen'],
  );

  my ($legend, $colour, $style, $border, $label, $text, $box_border);

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


  my ($x,$y) = (0, 0.7);
  if($vc->isa('Bio::EnsEMBL::Compara::CAFEGeneFamily')) {
    foreach my $branch (@branches) {
      ($legend, $colour, $style) = @$branch;
      if ($legend =~ /N number/) {
        $self->_draw_symbol($im_width, $x, $y, $NO_OF_COLUMNS, $BOX_WIDTH, $th, $fontsize, $fontname, $legend, $colour, $style);       #function to draw the symbol for n numbers, only be called for this specific legend        
      } else {
        if($legend eq 'Expansion' || $legend eq 'Contraction') {
          $self->push($self->Rect({
                'x'         => $im_width * $x/$NO_OF_COLUMNS,
                'y'         => $y * ( $th + 3 ) + 32 + $th,
                'width'     => 20,
                'height'    => 1,
                'bordercolour' => $colour,
              })
            );
        } else {
          $self->push($self->Line({
            'x'         => $im_width * $x/$NO_OF_COLUMNS,
            'y'         => $y * ( $th + 3 ) + 32 + $th,
            'width'     => 20,
            'height'    => 0,
            'colour'    => $colour,
            'dotted'    => $style,
            })
          );  
        }
      }      
      $label = $self->_create_label($im_width, $x, $y + 2, $NO_OF_COLUMNS, $BOX_WIDTH, $th, $fontsize, $fontname, $legend);
      
      $y = 1.5 if ($legend =~ /N number/);
      $self->push($label);
      $y+=1.2;      
    }
  } else {
    foreach my $branch (@branches) {
      ($legend, $colour, $style) = @$branch;  
      if($colour eq 'header') {       
        $label = $self->_create_label($im_width, ($x-0.05), $y, $NO_OF_COLUMNS, $BOX_WIDTH - 8, $th, $fontsize+0.6, $fontname, $legend);
        $self->push($label);
        $y = $y + 1.5;
        $x = 0.02;
      } else {
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
        $y+=1.2;
      }
    }
  }
  
  ($x, $y) = (1, 0.7);
  foreach my $ortho (@orthos) {
    my $bold_colour;
    ($legend, $colour, $text, $bold_colour) = @$ortho;
    if($colour eq 'header') {       
      $label = $self->_create_label($im_width, ($x-0.07), $y, $NO_OF_COLUMNS, $BOX_WIDTH - 8, $th, $fontsize+0.6, $fontname, $legend);
      $self->push($label);
      $y = $y + 1.5;            
    } else {
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
      $y+=1.2;
    }
  }

  ($x, $y) = (2, 0.7);
  foreach my $node (@nodes) {
    my $modifier;
    ($legend, $colour, $modifier) = @$node;
    my $bold = (defined $modifier and ($modifier eq 'bold'));
    if($colour eq 'header') {       
      $label = $self->_create_label($im_width, ($x-0.07), $y, $NO_OF_COLUMNS, $BOX_WIDTH - 8, $th, $fontsize+0.6, $fontname, $legend);
      $self->push($label);
      $y = $y + 1.5;            
    } else {
      $x = 2.5 if($vc->isa('Bio::EnsEMBL::Compara::CAFEGeneFamily'));
      $self->push($self->Rect({
          'x'         => $im_width * $x/$NO_OF_COLUMNS - $bold,
          'y'         => $y * ( $th + 3 ) + $th - $bold,
          'width'     => 5 + 2 * $bold,
          'height'    => 5 + 2 * $bold,
          'colour'    => $colour,
          'bordercolour' => ($vc->isa('Bio::EnsEMBL::Compara::CAFEGeneFamily')) ? "black" : $colour,
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
      $y+=1.2;
    }
  }

  ($x, $y) = (2.7, 0.7);  
  foreach my $poly (@polys) {    
    ($legend, $colour, $box_border) = @$poly;
    my $px = $im_width * $x/$NO_OF_COLUMNS;
    my $py = $y * ( $th + 3 ) + 8 + $th;
    my($width,$height) = (12,12);

    # a hack to get a header for each column in the legend    
    if($colour eq 'header') {
      $label = $self->_create_label($im_width, ($x-0.1), $y, $NO_OF_COLUMNS, $BOX_WIDTH - 8, $th, $fontsize+0.6, $fontname, $legend);
      $self->push($label);
      $y = $y + 1.5;
    } else {      
      #draw the triangles and label
      $self->push($self->Poly({
        'points' => [ $px, $py,
                      $px + $width, $py - ($height / 2 ),
                      $px + $width, $py + ($height / 2 ) ],
        'colour'   => $colour,
      }) );
      $label = $self->_create_label($im_width, $x, $y, $NO_OF_COLUMNS, $BOX_WIDTH - 8, $th, $fontsize, $fontname, $legend);
      $self->push($label);
      $y+=1.2;
    }
  }
  
  ($x, $y) = (3.55, 0.7);
  foreach my $collapsed_box (@collapsed_boxes) {
    ($legend, $colour, $box_border) = @$collapsed_box;
    my $px = $im_width * $x/$NO_OF_COLUMNS;
    my $py = $y * ( $th + 3 ) + 8 + $th;
    my($width,$height) = (12,12);

    # a hack to get a header for each column in the legend    
    if($colour eq 'header') {
      $label = $self->_create_label($im_width, ($x-0.1), $y, $NO_OF_COLUMNS, $BOX_WIDTH - 8, $th, $fontsize+0.6, $fontname, $legend);
      $self->push($label);
      $y = $y + 1.5;
    } else {
      $self->draw_box($im_width, $x, $y, $NO_OF_COLUMNS, $th, undef, undef, $box_border, $colour);
      $label = $self->_create_label($im_width, $x, $y, $NO_OF_COLUMNS, $BOX_WIDTH - 8, $th, $fontsize, $fontname, $legend);
      $self->push($label);
      $y+=1.5;       
    }    
  }

  ($x, $y) = (4.37, 0.7);  
  foreach my $box (@boxes) {
    ($legend, $colour, $border) = @$box;
    if($colour eq 'header') {
#       #one off drawing of a box next to the label
#       $self->push($self->Rect({
#           'x'         => $x+1370,
#           'y'         => $y+21,
#           'width'     => 7,
#           'height'    => 7,
#           'bordercolour' => 'navyblue',
#          })
#       );    
      $label = $self->_create_label($im_width, ($x-0.1), $y, $NO_OF_COLUMNS, $BOX_WIDTH - 10, $th, $fontsize+0.6, $fontname, $legend);
      $self->push($label);      
      $y = $y + 1.5;
    } else {     
      #Drawing boxes if border present, else can draw something else      
      if($border) {          
          $self->draw_box($im_width, $x, $y, $NO_OF_COLUMNS, $th, undef, undef, $border, $colour);
          $label = $self->_create_label($im_width, $x, $y, $NO_OF_COLUMNS, $BOX_WIDTH - 10, $th, $fontsize, $fontname, $legend);
          $self->push($label);
          $y+=1.5;          
      }
    }

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

#function to draw boxes in legend
sub draw_box {
  my ($self, $im_width, $x, $y, $NO_OF_COLUMNS, $th, $width, $height, $border, $colour) = @_;
  
  if($border) {
    #top horizontal line for border
    $self->push($self->Rect({
      'x'         => $im_width * $x/$NO_OF_COLUMNS,
      'y'         => $y * ( $th + 3 ) + 1 + $th,
      'width'     => 10,
      'height'    => 0,
      'colour'    => $border,
      })
    );
    #left vertical line for border
    $self->push($self->Rect({
      'x'         => $im_width * ($x-0.005)/$NO_OF_COLUMNS, #the lower the value, the more to the left (<-) it is
      'y'         => $y * ( $th + 3 ) + 1 + $th, # the lower the value, the higher up it is
      'width'     => 0,
      'height'    => 10,
      'colour'    => $border,
      })
    );  
    #right vertical line for border
    $self->push($self->Rect({
      'x'         => $im_width * ($x+0.0325)/$NO_OF_COLUMNS,
      'y'         => $y * ( $th + 3 ) + 1 + $th, 
      'width'     => 0,
      'height'    => 10,
      'colour'    => $border,
      })
    );
    #bottom horizontal line for border
    $self->push($self->Rect({
      'x'         => $im_width * $x/$NO_OF_COLUMNS,
      'y'         => ($y+0.08) * ( $th + 3 ) + 10 + $th,
      'width'     => 10,
      'height'    => 0,
      'colour'    => $border,
      })
    );    
  }
  #drawing middle square with fill colour
  $self->push($self->Rect({
    'x'         => $im_width * $x/$NO_OF_COLUMNS,
    'y'         => $y * ( $th + 3 ) + 2 + $th,
    'width'     => 10,
    'height'    => 8,
    'colour'    => $colour,
    })
  );
}
        
#function to draw the n members symbol
sub _draw_symbol {
  my ($self,$im_width, $x, $y, $NO_OF_COLUMNS, $BOX_WIDTH, $th, $fontsize, $fontname, $legend, $colour, $style) = @_;
# Drawing first horizontal line    
  $self->push($self->Line({
    'x'         => 13,
    'y'         => $y * ( $th + 3 ) + 15 + $th,
    'width'     => 10,
    'height'    => 0,
    'colour'    => $colour,
    'dotted'    => $style,
    })
  );
# Draw vertical line      
  $self->push($self->Line({
    'x'         => 13,
    'y'         => $y * ( $th + 3 ) + 15 + $th,
    'width'     => 0,
    'height'    => 10,
    'colour'    => $colour,
    'dotted'    => $style,
    })
  );
#Draw horizontal line next to the N      
  $self->push($self->Line({
    'x'         => -1,
    'y'         => $y * ( $th + 3 ) + 32 + $th,
    'width'     => 10,
    'height'    => 0,
    'colour'    => $colour,
    'dotted'    => $style,
    })
  );

# Draw N as a label
  my $n_label = $self->_create_label($im_width, '0', '2.7', '1', '2', $th, '7', $fontname, 'N');
  $self->push($n_label);      
  
  $self->push($self->Line({
    'x'         => 13,
    'y'         => $y * ( $th + 3 ) + 38 + $th,
    'width'     => 0,
    'height'    => 10,
    'colour'    => $colour,
    'dotted'    => $style,
    })
  );
       
  $self->push($self->Line({
    'x'         => 13,
    'y'         => $y * ( $th + 3 ) + 48 + $th,
    'width'     => 10,
    'height'    => 0,
    'colour'    => $colour,
    'dotted'    => $style,
    })
  );  
}

1;
      
