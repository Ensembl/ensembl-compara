package Bio::EnsEMBL::GlyphSet::P_variation_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;
  
  return unless $self->strand == -1;
  
  my $config   = $self->{'config'};
  my $features = $config->{'P_variation_legend'};
  $features->{'Insert'} = { colour => 'blue', shape => 'Poly' };
  return unless $features;
  
  my $im_width = $config->image_width;
  my $width    = 10;
  my $columns  = 4;
  my $x        = 0;
  my $h        = 4;
  my @colours;
  
  my ($fontname, $fontsize) = $self->get_font_details('legend');
  my @res = $self->get_text_width(0, 'X', '', 'font' => $fontname, 'ptsize' => $fontsize);
  my $th  = $res[3] - ($h / 2);
  
  # Set up a separating line
  $self->push($self->Rect({
    x             => 0,
    y             => 0,
    width         => $im_width, 
    height        => 0,
    colour        => 'grey50',
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1
  }));
  
  foreach (sort keys %$features) {
    my $colour = $features->{$_}->{'colour'};
    
    if ($features->{$_}->{'shape'} eq 'Poly') {
      my $dir = $_ eq 'Insert' ? 1 : -1;
      my $y   = $th + $h - ($dir * $h / 2);
      
      $self->push($self->Poly({
        colour    => $colour,
        absolutey => 1,
        absolutex => 1,
        points    => [ 
          $im_width * $x/$columns - ($dir * 3), $y,
          $im_width * $x/$columns,              $y + ($dir * 4),
          $im_width * $x/$columns + ($dir * 3), $y
        ]
      }));
    } else {
      $self->push($self->Rect({
        x             => $im_width * $x/$columns,
        y             => $th + ($h / 2),
        width         => $h,
        height        => $h,
        colour        => $colour,
        absolutex     => 1,
        absolutey     => 1,
        absolutewidth => 1
      }));
    }
    
    $self->push($self->Text({
      x             => $im_width * $x/$columns + $width,
      y             => $th,
      height        => $th,
      valign        => 'center',
      halign        => 'left',
      ptsize        => $fontsize,
      font          => $fontname,
      colour        => 'black',
      text          => $_,
      absolutey     => 1,
      absolutex     => 1,
      absolutewidth => 1
    }));
    
    $x++;
  }
}

1;
        
