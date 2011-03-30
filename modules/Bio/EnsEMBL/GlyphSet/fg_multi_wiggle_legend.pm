package Bio::EnsEMBL::GlyphSet::fg_multi_wiggle_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;
  
  return unless $self->strand == -1;
  
  my $config = $self->{'config'};
  
  return unless $config->{'fg_multi_wiggle_legend'};

  my $features = $config->{'fg_multi_wiggle_legend'}->{'colours'};
  
  return unless $features;
  
  my $box_width             = 20;
  my $no_of_columns         = 4;
  my $im_width              = $config->get_parameter('panel_width');
  my ($x, $y)               = (0, 0);
  my ($fontname, $fontsize) = $self->get_font_details('legend');
  my @res                   = $self->get_text_width(0, 'X', '', 'font' => $fontname, 'ptsize' => $fontsize);
  my $th                    = $res[3];
  my $flag                  = 0;
  
  foreach (sort keys %$features) {  
    my $legend = $_;
    
    my $colour =  $features->{$_} || 'black';
    
    $flag = 1;
    
    $self->push($self->Rect({
        x             => $im_width * $x/$no_of_columns,
        y             => $y * ($th + 3) + 2,
        width         => $box_width,
        height        => $th-2,
        colour        => $colour,
        absolutey     => 1,
        absolutex     => 1,
        absolutewidth => 1,
    }));
    $self->push($self->Text({
        x             => $im_width * $x/$no_of_columns + $box_width,
        y             => $y * ($th + 3),
        height        => $th,
        valign        => 'center',
        halign        => 'left',
        ptsize        => $fontsize,
        font          => $fontname,
        colour        => 'black',
        text          => " $legend",
        absolutey     => 1,
        absolutex     => 1,
        absolutewidth => 1
    }));
    
    $x++;
    
    if ($x == $no_of_columns) {
      $x = 0;
      $y++;
    }
  }
  
  # Set up a separating line
  my $rect = $self->Rect({
    x             => 0,
    y             => 0,
    width         => $im_width,
    height        => 0,
    colour        => 'grey50',
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
  });
  
  $self->push($rect);
  $self->errorTrack('No Cell/Tissue regulation data in this panel') unless $flag;
}

1;
