package Bio::EnsEMBL::GlyphSet::draggable;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

our $counter;

sub _colour_background {
  return 0;
}

sub _init {
  my $self = shift;

  my $container = $self->{'container'};

  my $strand = $self->strand;
  my $start  = $container->start;
  my $end    = $container->end;
  
  my $glyph = $self->Rect({
    x      => 0,
    y      => 6,
    width  => $end - $start + 1,
    height => 0,
    color  => 'black'
  });

  $self->push($glyph);

  my $A = $strand > 0 ? 1 : 0;

  my $href = join('|',  
    '#drag', $self->get_parameter('slice_number'), $self->species,
    $container->seq_region_name, $start, $end, $container->strand
  );
  
  my @common = (
    'y'     => $A,
    'style' => 'fill',
    'z'     => -10,
    'href'  => $href,
    'alt' => 'Click and drag to select a region',
    'class' => 'drag' . ($self->get_parameter('multi') ? ' multi' : $self->get_parameter('compara') ? ' align' : '')
  );
  
  $self->join_tag($glyph, 'draggable', { 'x' => $A, @common });
  $self->join_tag($glyph, 'draggable', { 'x' => 1 - $A, @common });
}

1;
