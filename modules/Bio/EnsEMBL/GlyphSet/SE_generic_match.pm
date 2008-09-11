package Bio::EnsEMBL::GlyphSet::SE_generic_match;
use base qw(Bio::EnsEMBL::GlyphSet::TSE_generic_match);
use strict;

sub _init {
  my $self = shift;
  my $all_matches = $self->cache('align_object')->{'evidence'};
  $self->draw_glyphs( $all_matches );
}

1;
