package Bio::EnsEMBL::GlyphSet::draggable;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Space;

sub init_label {
  my ($self) = @_;
  return;
}

our $counter;

sub _init {
  my ($self) = @_;

  my $strand = $self->strand;

  my $Config = $self->{'config'};

  my $start   = $self->{'container'}->start();
  my $end     = $self->{'container'}->end();
  
  my $glyph = new Sanger::Graphics::Glyph::Rect({
    'x'         => 0,
    'y'         => 6,
    'width'     => $end-$start,
    'height'    => 0
  });

  $self->push($glyph);
  my $A = $strand > 0 ? 1 : 0;
  my $href = join '|',
    '#drag',
    $self->{'config'}->{'slice_number'},
    $self->{'config'}->{'species'},
    $self->{'container'}->seq_region_name,
    $start,
    $end,
    $self->{'container'}->strand;

  my @common = (
    'y'     => $A,
    'style' => 'fill',
    'z'     => -10,
    'href'  => $href
  );
  $self->join_tag( $glyph, 'draggable', { 'x' =>   $A, @common });
  $self->join_tag( $glyph, 'draggable', { 'x' => 1-$A, @common });
}

1;
