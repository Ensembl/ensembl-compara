package Bio::EnsEMBL::GlyphSet::gene_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub _init {
  my $self = shift;
  
  return unless $self->strand == -1;

  my $box_width = 20;
  my $coloums   = 2;
  my $config    = $self->{'config'};
  my $im_width  = $config->image_width;
  my @colours;
  
  return unless $config->{'legend_features'};
  
  my %features = %{$config->{'legend_features'}};
  
  return unless %features;
  
  # Set up a separating line
  my $rect = $self->Rect({
    x             => 0,
    y             => 0,
    width         => $im_width, 
    height        => 0,
    colour        => 'grey50',
    absolutey     => 1,
    absolutex     => 1,
    absolutewidth => 1
  });
  
  $self->push($rect);
  
  my ($x, $y) = (0, 0);
  my ($fontname, $fontsize) = $self->get_font_details('legend');
  my @res = $self->get_text_width(0, 'X', '', 'font' => $fontname, 'ptsize' => $fontsize);
  my $th = $res[3];
  my $pix_per_bp = $self->scalex;
  my %seen;
  
  foreach my $type (sort { $features{$a}->{'priority'} <=> $features{$b}->{'priority'} } keys %features) {
    @colours = $type eq 'joins' ? 
      map { $_, $features{$type}->{'legend'}->{$_} } sort keys %{$features{$type}->{'legend'}} : 
      @{$features{$type}->{'legend'}};
    
    $y++ unless $x == 0;
    $x = 0;
    
    while (my ($legend, $colour) = splice @colours, 0, 2) {
      next if $seen{"$legend:$colour"};
      
      $seen{"$legend:$colour"} = 1;
      
      my $join = $legend =~ /orthologue|paralogue|alleles/i;
      
      $self->push($self->Rect({
        x             => $im_width * $x/$coloums,
        y             => $y * ($th + 3) + ($join ? ($th/2) : 2),
        width         => $box_width, 
        height        => $join ? 0.5 : $th-2,
        colour        => $colour,
        absolutey     => 1,
        absolutex     => 1,
        absolutewidth => 1
      }));
      
      $self->push($self->Text({
        x             => $im_width * $x/$coloums + $box_width,
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
      
      if ($x == $coloums) {
        $x = 0;
        $y++;
      }
    }
  }
}

1;
        
