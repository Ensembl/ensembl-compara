package Bio::EnsEMBL::GlyphSet::meth_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub colourmap {
  return $_[0]->{'config'}->hub->colourmap;
}

sub _init {
  my $self = shift;
  
  return unless $self->strand == -1;

  my $box_width = 20;
  my $columns   = 3;
  my $config    = $self->{'config'};
  my $im_width  = $config->get_parameter('panel_width');
  
  return unless $config->{'_meth_legend'};
   
  my ($x, $y) = (0, 0);
    
  my %font        = $self->get_font_details('legend', 1);
  my ($t1,$t2,$text_width,$text_height) =
    $self->get_text_width(0, 'X', '', %font);
  
  my @cg = $self->{'config'}->colourmap
                ->build_linear_gradient(10, [ qw(yellow green blue) ]);
  my $bw = 20;
  for my $i (0..@cg) {
    if($i<@cg) {
      $self->push($self->Rect({
        x             => $i * $bw,
        y             => 2,
        width         => $bw, 
        height        => $text_height - 2,
        colour        => $cg[$i],
        absolutey     => 1,
        absolutex     => 1,
        absolutewidth => 1
      }));
    }
    $self->push($self->Text({
      x             => $i* $bw - ($text_width*($i?2:0)/3) ,
      y             => $text_height,
      height        => $text_height,
      valign        => 'center',
      halign        => 'center',
      colour        => 'black',
      text          => sprintf("%d",$i*10)." ",
      absolutey     => 1,
      absolutex     => 1,
      absolutewidth => 1,
      font          => 'Small',
    }));    
  }
  $self->push($self->Text({
    x             => (@cg+0.5)*$bw,
    y             => 0,
    height        => $text_height,
    valign        => 'center',
    halign        => 'center',
    colour        => 'black',
    text          => "% methylated reads",
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
    %font
  }));      
}

1;
