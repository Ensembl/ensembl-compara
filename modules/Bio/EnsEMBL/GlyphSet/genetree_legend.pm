package Bio::EnsEMBL::GlyphSet::genetree_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet::legend);

sub render_normal {
  my ($self) = @_;

  return unless ($self->strand() == -1);

  my $vc            = $self->{'container'};
  my $other_gene            = $self->{highlights}->[5];
  my $highlight_ancestor    = $self->{highlights}->[6];

  my $cafe = $vc->isa('Bio::EnsEMBL::Compara::CAFEGeneFamily');

  $self->init_legend($cafe?4:6);

  $self->newline(); # Make room for "LEGEND"
  $self->newline();
  
  # Branch length vertical group
  if($cafe) {
    $self->add_vgroup_to_legend([
      { legend => "N number of members",
        colour => "blue", style => "nsymbol" },
      { legend => "Expansion", height => 1,
        colour => "#800000", style => 'line' },
      { legend => "Contraction", height => 1,
        colour => "#008000", style => 'line' },
      { legend => "No significant chage",
        colour => "blue", style => 'line' },
    ],'');
  } else {
    $self->add_vgroup_to_legend([
      { legend => "x1 branch length",
        colour => "blue", style => 'line' },
      { legend => "x10 branch length", dashed => 1,
        colour => "blue", style => 'line' },
      { legend => "x100 branch length", dashed => 1,
        colour => "red", style => 'line' },
    ],"Branch Length");
  }

  # Nodes vertical group
  my @nodes;
  if($cafe) {
    @nodes = (
      { legend => 'Nodes with 0 members ',    colour => 'grey'   },
      { legend => 'Nodes with 1-5 members',   colour => '#FEE391'},
      { legend => 'Nodes with 6-10 members',  colour => '#FEC44F'},
      { legend => 'Nodes with 11-15 members', colour => '#FE9929'},
      { legend => 'Nodes with 16-20 members', colour => '#EC7014'},
      { legend => 'Nodes with 21-25 members', colour => '#CC4C02'},
      { legend => 'Nodes with >25 members',   colour => '#8C2D04'},
    );
    $_->{'border'} = 'black' for(@nodes);
  } else {
    @nodes = (
      { legend => 'gene node',
        colour => 'white', border => 'navyblue' },
      { legend => 'speciation node',  colour => 'navyblue'},
      { legend => 'duplication node', colour => 'red3'},
      { legend => 'ambiguous node',   colour => 'turquoise'},
      { legend => 'gene split event',
        colour => 'SandyBrown', border => 'navyblue' },
    );
  }
  if ($highlight_ancestor) {
    push @nodes,{ legend => "ancestor node", 
                  colour => '444444', envelop => 1 };
  }
  $self->add_vgroup_to_legend(\@nodes,$cafe?'':'Nodes',{
    width => 5,
    height => 5
  });
 
  # Genes vertical group
  if($other_gene) {
    $self->add_vgroup_to_legend([
      { legend => "gene of interest",
        colour => "darkgreen", text => "Gene ID" },
      { legend => "within-sp. paralog",
        colour => "blue", text => "Gene ID" },
      { legend => "other gene",
        colour => "red", text => "Gene ID" },
      { legend => "other within-sp. paralog",
        colour => "black", text => "Gene ID" },
      ],"Genes",{
        bold => 1,
        style => 'text',
    });
  } elsif($cafe) {
    $self->add_vgroup_to_legend([
      { legend => "Species of interest",
        colour => "red", text => "Species" },
      { legend => "Species with no genes",
        colour => "grey", text => "Species" },
      ],'',{
        style => "text",
    });
  } else {
    $self->add_vgroup_to_legend([
      { legend => "gene of interest",
        colour => "red", text => "Gene ID" },
      { legend => "within-sp. paralog",
        colour => "blue", text => "Gene ID" }
    ],"Genes",{
      style => "text",
    });
  }

  unless($cafe) {
    my $alphabet = "AA";
    if (UNIVERSAL::isa($vc, "Bio::EnsEMBL::Compara::NCTree")) {
      $alphabet = "Nucl.";
    }  
  
    # Collapsed Nodes vertical group
    $self->add_vgroup_to_legend([    
      { legend => 'collapsed sub-tree', colour => 'grey' },
      { legend => 'collapsed (gene of interest)', colour => 'red' },
      { legend => 'collapsed (paralog)', colour => 'royalblue' },
      ],"Collapsed nodes",{
        style => 'collapsed'
    });

    # Collapsed Alignments vertical group
    $self->add_vgroup_to_legend([
      { legend => "0 - 33% Aligned $alphabet",
        colour => 'white', border => 'darkgreen'       },
      { legend => "33 - 66% Aligned $alphabet",
        colour => 'yellowgreen', border => 'darkgreen' },
      { legend => "66 - 100% Aligned $alphabet",
        colour => 'darkgreen', border => 'darkgreen'   },
      ],"Collapsed Alignments",{
        width => 12,
        height => 12
    });

    # Expanded Alignments vertical group
    $self->add_vgroup_to_legend([
      { legend => "Gap", 
        colour => "white", border => "yellowgreen" },
      { legend => "Aligned $alphabet", 
        colour => "yellowgreen", border => "yellowgreen" },
      ],"Expanded Alignments",{
        width => 12,
        height => 12
    });
  }

  # The word "LEGEND"
  my( $fontname, $fontsize ) = $self->get_font_details( 'legend' );
  my @res = $self->get_text_width( 0, 'X', '',
                                  'font'=>$fontname, 'ptsize' => $fontsize);
  $self->push($self->Text({
        'x'         => 0,
        'y'         => $res[3]/2,
        'height'    => $res[3],
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
}

# The triangle
sub _icon_collapsed {
  my ($self,$x,$y,$k) = @_;

  $self->push($self->Poly({
    'points' => [ $x, $y + 6,
                  $x + 12, $y ,
                  $x + 12, $y + 12 ],
    'colour'   => $k->{'colour'},
  }));
  return (12,12);
}

# As used in CAFE trees
sub _icon_nsymbol {
  my ($self,$x,$y,$k) = @_;

  # Line segment from (x1,y1)-(x2,y2) is [x1,y1,x2,y2]
  # x2 >= x1, y2 >=y1 is probably required by Line glyph
  my @lines = ([0,2,1.5,2],  # mid horiz
               [3,0,5,0],  # top horiz
               [3,4,5,4],  # bot horiz
               [3,0,3,1.25],  # top vert
               [3,2.75,3,4]); # bot vert
               
  my ($w,$h) = ($self->{'box_width'}/4,$self->{'text_height'}*3/4);
  foreach my $line (@lines) {
    $self->push($self->Line({
      x => $x + $line->[0]*$w,
      y => $y + $line->[1]*$h,
      width => ($line->[2]-$line->[0])*$w,
      height => ($line->[3]-$line->[1])*$h,
      absolutex => 1, absolutey => 1, absolutewidth => 1,
      colour => $k->{'colour'},
    }));
  }
  my %nfont = %{$self->{'font'}};
  $nfont{'ptsize'} *= 0.8;
  my @res = $self->get_text_width(0,'N','',%nfont);
  $self->push($self->Text({
    x => $x + $w*3 - $res[2]/2,
    y => $y + $h*2 - $res[3]/2,
    text => 'N',
    height => $res[3],
    width => $res[2],
    halign => 'left',
    valign => 'top',
    absolutex => 1, absolutey => 1, absolutewidth => 1,
    colour => 'black',
    %nfont,
  }));
  return ($w*5,$h*4);
}

1;
      
