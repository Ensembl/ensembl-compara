package Bio::EnsEMBL::GlyphSet::diff_legend;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

sub colourmap {
  return $_[0]->{'config'}->hub->colourmap;
}

sub _init {
  my $self = shift;
  
  return unless $self->strand == -1;

  my $box_width = 20;
  my $columns   = 2;
  my $config    = $self->{'config'};
  my $im_width  = $config->get_parameter('panel_width');
  
  return unless $config->{'_difference_legend'};
   
  my ($x, $y) = (0, 0);
    
  my %font        = $self->get_font_details('legend', 1);
  my $text_height = [ $self->get_text_width(0, 'X', '', %font) ]->[3];
  
  my @blocks = (
    { 
      legend => 'Insert relative to reference',
      colour => '#2aa52a',
      border => 'black',
    },{
      legend => 'Delete relative to reference',
      colour => 'red',
    },{
      legend => 'Cluster of inserts at this scale (zoom to resolve)',
      colour => '#2aa52a', 
      overlay => '..',
      border => 'black',
      test => '_difference_legend_dots',
    },{
      legend => 'Cluster of deletes at this scale (zoom to resolve)',
      colour => '#ffdddd',
      test => '_difference_legend_pink',
    },{
      legend => 'Large insert shown truncated due to image scale or edge',
      colour => '#94d294',
      overlay => '...',
      test => '_difference_legend_el',
    },{
      legend => 'Match',
      colour => '#ddddff',
    });
  
  foreach my $b (@blocks) {
    my ($legend,$colour) = ($b->{'legend'},$b->{'colour'});

    if($b->{'test'}) {
      next unless $config->{$b->{'test'}};
    }

    my $text_width = [ $self->get_text_width(0, $b->{'overlay'}||'X', '', %font) ]->[2];
    $self->push($self->Rect({
      x             => $im_width * $x/$columns,
      y             => $y * ($text_height + 3) +  2,
      width         => $box_width, 
      height        => $text_height - 2,
      colour        => $colour,
      bordercolour  => $b->{'border'},
      absolutey     => 1,
      absolutex     => 1,
      absolutewidth => 1
    }));
    
    # overlay
    if($b->{'overlay'}) {
      $self->push($self->Text({
        x             => $im_width * $x/$columns + $box_width/2 - $text_width/2,
        y             => $y * ($text_height + 3 ) - 2,
        height        => $text_height,
        valign        => 'center',
        halign        => 'left',
        colour        => $self->colourmap->contrast($colour),
        text          => $b->{'overlay'},
        absolutey     => 1,
        absolutex     => 1,
        absolutewidth => 1,
        %font
      }));
    }
    # legend
    $self->push($self->Text({
      x             => $im_width * $x/$columns + $box_width,
      y             => $y * ($text_height + 3),
      height        => $text_height,
      valign        => 'center',
      halign        => 'left',
      colour        => 'black',
      text          => " ".$b->{'legend'},
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
