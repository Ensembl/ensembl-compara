package Bio::EnsEMBL::GlyphSet::variation_legend;

use strict;

use Bio::EnsEMBL::Variation::Utils::Constants;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;

  return unless $self->strand == -1;
  
  my $config   = $self->{'config'}; 
  my %features = %{$config->{'variation_legend'} || {}};
  
  return unless %features;
  
  my $im_width              = $config->image_width;
  my $pix_per_bp            = $config->transform->{'scalex'};
  my ($fontname, $fontsize) = $self->get_font_details('legend');
  my $text_height           = [ $self->get_text_width(0, 'X', '', font => $fontname, ptsize => $fontsize) ]->[3];
  my %labels                = map { $_->display_term => [ $_->rank, $_->label ] } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my $type                  = 'all';
  my $box_width             = 20;
  my $cols                  = 3;
  my ($x, $y)               = (0, 0);
  
  foreach (sort { $labels{$a}[0] <=> $labels{$b}[0] } keys %features) {
    my $colour = $features{$_};
    my $tocolour;
    
    ($tocolour, $colour) = ($1, $2) if $colour =~ /(.*):(.*)/;
    
    $self->push($self->Rect({
      x                   => $im_width * $x / $cols,
      y                   => $y * ($text_height + 3) + 2,
      width               => $box_width,
      height              => $text_height - 2,
      "${tocolour}colour" => $colour,
      absolutey           => 1,
      absolutex           => 1,
      absolutewidth       => 1,
    }));
    
    $self->push($self->Text({
      x             => $im_width * $x / $cols + $box_width + 3,
      y             => $y * ($text_height + 3),
      height        => $text_height,
      valign        => 'center',
      halign        => 'left',
      ptsize        => $fontsize,
      font          => $fontname,
      colour        => 'black',
      text          => " $labels{$_}[1]",
      absolutey     => 1,
      absolutex     => 1,
      absolutewidth => 1
    }));
    
    if (++$x == $cols) {
      $x = 0;
      $y++;
    }
  }
  
  # separating line
  $self->push($self->Rect({
    x             => 0,
    y             => 0,
    width         => $im_width,
    height        => 0,
    colour        => 'grey50',
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1,
  }));
}

1;
