package Bio::EnsEMBL::GlyphSet::alignslice_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;
  
  return unless $self->strand == -1;
  
  my $config   = $self->{'config'};
  my $features = $config->{'alignslice_legend'};
  
  return unless $features;
  
  my $im_width   = $config->image_width;
  my $width      = 7;
  my $columns    = 2;
  my $x          = 0;
  my $y          = 0;
  my $h          = 3;
  my @colours;
  my %seen;
  
  my ($fontname, $fontsize) = $self->get_font_details('legend');
  my @res = $self->get_text_width(0, 'X', '', 'font' => $fontname, 'ptsize' => $fontsize);
  my $th = $res[3];
  
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
  
  foreach (sort { $features->{$a}->{'priority'} <=> $features->{$b}->{'priority'} } keys %$features) {
    my $legend = $features->{$_}->{'legend'};
    
    next if $seen{"$legend:$_"};
    
    $self->push($self->Poly({
      colour    => $_,
      absolutey => 1,
      absolutex => 1,
      points    => [ 
        $im_width * $x/$columns - 2, $h,
        $im_width * $x/$columns, $h + 6,
        $im_width * $x/$columns + 2, $h
      ]
    }));
    
    $self->push($self->Text({
     x             => $im_width * $x/$columns + $width,
     y             => $y * ($th + 3),
     height        => $th,
     valign        => 'center',
     halign        => 'left',
     ptsize        => $fontsize,
     font          => $fontname,
     colour        => 'black',
     text          => $legend,
     absolutey     => 1,
     absolutex     => 1,
     absolutewidth => 1
    }));
    
    $seen{"$legend:$_"} = 1;
    $x++;
    
    if ($x == $columns) {
      $x = 0;
      $y++;
      $h += $th + 3;
    }
  }
}

1;
        
