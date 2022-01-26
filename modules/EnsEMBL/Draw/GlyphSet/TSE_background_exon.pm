=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Draw::GlyphSet::TSE_background_exon;

use strict;

use base qw(EnsEMBL::Draw::GlyphSet);

### Needed for drawing vertical lines on supporting evidence view

sub _init {
  my ($self) = @_;
  my $wuc  = $self->{'config'};
  my $flag = $self->my_config('flag');

  #retrieve tag locations and colours (identified by TSE_transcript track)
  foreach my $tag (@{$wuc->cache('vertical_tags') || []}) {
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
