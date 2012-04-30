package Bio::EnsEMBL::GlyphSet::gene_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;
  
  return unless $self->strand == -1;

  my $box_width = 20;
  my $columns   = 2;
  my $config    = $self->{'config'};
  my $im_width  = $config->get_parameter('panel_width');
  my ($join, @colours);
  
  return unless $config->{'legend_features'};
  
  my %features = %{$config->{'legend_features'}};
  
  return unless %features;
 
  my ($x, $y) = (0, 0);
  my %font        = $self->get_font_details('legend', 1);
  my $text_height = [ $self->get_text_width(0, 'X', '', %font) ]->[3];
  my $pix_per_bp  = $self->scalex;
  my %seen;
  
  foreach my $type (sort { $features{$a}{'priority'} <=> $features{$b}{'priority'} } keys %features) {
    $join    = $type eq 'joins';
    @colours = $join ? map { $_, $features{$type}{'legend'}{$_} } sort keys %{$features{$type}{'legend'}} : @{$features{$type}{'legend'}};
    
    $y++ unless $x == 0;
    $x = 0;
    
    while (my ($legend, $colour) = splice @colours, 0, 2) {
      next if $seen{"$legend:$colour"};
      
      $seen{"$legend:$colour"} = 1;
      
      $self->push($self->Rect({
        x             => $im_width * $x/$columns,
        y             => $y * ($text_height + 3) + ($join ? $text_height / 2 : 2),
        width         => $box_width, 
        height        => $join ? 0.5 : $text_height - 2,
        colour        => $colour,
        absolutey     => 1,
        absolutex     => 1,
        absolutewidth => 1
      }));
      
      $self->push($self->Text({
        x             => $im_width * $x/$columns + $box_width,
        y             => $y * ($text_height + 3),
        height        => $text_height,
        valign        => 'center',
        halign        => 'left',
        colour        => 'black',
        text          => " $legend",
        absolutey     => 1,
        absolutex     => 1,
        absolutewidth => 1,
        %font
      }));
      
      $x++;
      
      if ($x == $columns) {
        $x = 0;
        $y++;
      }
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
}

1;
        
