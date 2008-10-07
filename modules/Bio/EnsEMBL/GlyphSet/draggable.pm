package Bio::EnsEMBL::GlyphSet::draggable;
use strict;
use base qw(Bio::EnsEMBL::GlyphSet);

our $counter;

sub _init {
  my ($self) = @_;

  my $strand = $self->strand;

  my $Config = $self->{'config'};

  my $start   = $self->{'container'}->start();
  my $end     = $self->{'container'}->end();
  
  my $glyph = $self->Rect({
    'x'         => 0,
    'y'         => 6,
    'width'     => $end-$start+1,
    'height'    => 0,
    'color'     => 'black'
  });

  $self->push($glyph);
  my $A = $strand > 0 ? 1 : 0;
  my $href = join '|',
    '#drag', $self->get_parameter('slice_number'),
    $self->{'config'}->{'species'}, $self->{'container'}->seq_region_name,
    $start, $end, $self->{'container'}->strand;

  my @common = (
    'y'     => $A,  'style' => 'fill',
    'z'     => -10, 'href'  => $href
  );
  $self->join_tag( $glyph, 'draggable', { 'x' =>   $A, @common });
  $self->join_tag( $glyph, 'draggable', { 'x' => 1-$A, @common });
}

1;
