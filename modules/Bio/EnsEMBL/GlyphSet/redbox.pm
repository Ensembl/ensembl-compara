package Bio::EnsEMBL::GlyphSet::redbox;
use strict;
use Bio::EnsEMBL::GlyphSet;
our @ISA = qw(Bio::EnsEMBL::GlyphSet);
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::ColourMap;

sub _init {
  my ($self) = @_;
  my $Container = $self->{'container'};
  my $Config    = $self->{'config'};
  my $offset    = $Container->start() - 1;
  my $strand    = $self->strand();
  my $col       = $Config->get( 'redbox', 'col' );
  my $zed       = $Config->get( 'redbox', 'zindex' );
  my $rbs       = $Config->get('_settings','red_box_start');
  my $rbe       = $Config->get('_settings','red_box_end');
  my $glyph = new Sanger::Graphics::Glyph::Rect({
    'x'            => $rbs - $offset,
    'y'            => 0,
    'width'        => $rbe-$rbs+1,
    'height'       => 0,
    'bordercolour' => $col,
    'absolutey'    => 1,
  });
  $self->push( $glyph );
  $self->join_tag(
    $glyph, 'redbox', $strand == -1 ? 0 : 1, 0, $col, '', $zed );
  $self->join_tag(
    $glyph, 'redbox', $strand == -1 ? 1 : 0, 0, $col, '', $zed );
}

1;
