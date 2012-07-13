package Bio::EnsEMBL::GlyphSet::P_variation_legend;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;
  
  return unless $self->strand == -1;
  
  my $config   = $self->{'config'};
  my $features = $config->{'P_variation_legend'};
  
  return unless $features;
  
  my ($fontname, $fontsize) = $self->get_font_details('legend');
  my $im_width = $config->image_width;
  my $width    = 10;
  my $columns  = 4;
  my $x        = 0;
  my $h        = 4;
  my @res      = $self->get_text_width(0, 'X', '', font => $fontname, ptsize => $fontsize);
  my $th       = $res[3] - ($h / 2);
  my $y        = $th;
  my %labels   = map { $_->SO_term => [ $_->rank, $_->label ] } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  
  $labels{'Insert'} = [ 9e9,     'Insert' ];
  $labels{'Delete'} = [ 9e9 + 1, 'Delete' ];
  
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
  
  foreach (sort { $labels{$a}[0] <=> $labels{$b}[0] } keys %$features) {
    my $colour = $features->{$_}{'colour'};
    my $text   = $labels{$_}[1];
    
    if ($features->{$_}{'shape'} eq 'Triangle') {
      my $dir = $text eq 'Insert' ? 1 : -1;
      
      $self->push($self->Triangle({
        width        => 6,
        height       => 4,
        mid_point    => [ $im_width * $x/$columns, $y + $h + $dir * (4 - $h / 2) ],
        direction    => $text eq 'Insert'? 'down' : 'up',
        bordercolour => 'black',
        absolutey    => 1,
        absolutex    => 1,
        no_rectangle => 1
      }));
    } else {
      $self->push($self->Rect({
        x             => $im_width * $x/$columns,
        y             => $y + ($h / 2),
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
      y             => $y,
      height        => $th,
      valign        => 'center',
      halign        => 'left',
      ptsize        => $fontsize,
      font          => $fontname,
      colour        => 'black',
      text          => $text,
      absolutey     => 1,
      absolutex     => 1,
      absolutewidth => 1
    }));
    
    $x++;
    
    if ($x == $columns) {
      $x = 0;
      $y += $th + 5;
    };
  }
}

1;
        
