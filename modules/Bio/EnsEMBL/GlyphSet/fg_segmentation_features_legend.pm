package Bio::EnsEMBL::GlyphSet::fg_segmentation_features_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;

  return unless $self->strand == -1;
  
  my $config = $self->{'config'};
  
  return unless $config->{'fg_segmentation_features_legend_features'};
  
  my %features = %{$self->my_config('colours')};

  return unless %features;

  my $box_width             = 20;
  my $no_of_columns         = 2;
  my $im_width              = $config->image_width;
  my ($x, $y)               = (0, 0);
  my ($fontname, $fontsize) = $self->get_font_details('legend');
  my @res                   = $self->get_text_width(0, 'X', '', 'font' => $fontname, 'ptsize' => $fontsize);
  my $th                    = $res[3];
  my $flag                  = 0;

  foreach (sort keys %features) {
    my $legend = $self->my_colour($_, 'text'); 
    
    next if $legend =~ /unknown/i; 
    
    my $colour = $self->my_colour($_);
    my $tocolour;
    
    $flag = 1;
    ($tocolour, $colour) = ($1, $2) if $colour =~ /(.*):(.*)/;
    $tocolour .= 'colour';
    
    $self->push($self->Rect({
        x             => $im_width * $x/$no_of_columns,
        y             => $y * ($th + 3) + 2,
        width         => $box_width,
        height        => $th-2,
        $tocolour     => $colour,
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
  $self->errorTrack('No Segmentation Features in this panel') unless $flag;
}

1;
