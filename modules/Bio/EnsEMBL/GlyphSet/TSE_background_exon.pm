package Bio::EnsEMBL::GlyphSet::TSE_background_exon;

use strict;

use base qw(Bio::EnsEMBL::GlyphSet);

#needed for drawing vertical lines on supporting evidence view

sub _init {
  my ($self) = @_;
  my $wuc  = $self->{'config'};
  my $flag = $self->my_config('flag');

  #retrieve tag locations and colours (identified by TSE_transcript track)
  foreach my $tag (@{$wuc->cache('vertical_tags')}) {
    my ($extra,$e,$s) = split ':', $tag->[0];
    my $col = $tag->[1];
    my $tglyph = $self->Space({
      'x' => $s,
      'y' => 0,
      'height' => 0,
      'width'  => $e-$s,
      'colour' => '$col',
    });
    $self->join_tag( $tglyph, $tag->[0], 1-$flag,  0, $col, 'fill', -99 );
    $self->join_tag( $tglyph, $tag->[0], $flag,    0, $col, 'fill', -99 );
    $self->push( $tglyph );
  }
}
1;
