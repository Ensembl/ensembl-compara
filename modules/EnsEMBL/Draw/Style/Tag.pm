=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::Style::Tag;

### Provides additional annotation to a track, eg. joins for compara
### or assembly exceptions

### Usage - in the GlyphSet's draw_features method, after creating
### the glyphs for the individual features, calculate the position of any
### desired tags and then add them to the track in a similar way 
### to the features themselves

use strict;
use warnings;
no warnings 'uninitialized';

use parent qw(EnsEMBL::Draw::Style);

sub create_glyphs {
### Create all the glyphs required by this style
### @return ArrayRef of EnsEMBL::Web::Glyph objects
  my $self = shift;

  my $data            = $self->data;
  my $track_config    = $self->track_config;

  foreach my $subtrack (@$data) {
    foreach my $feature (@{$subtrack->{'features'}||[]}) {
      $self->draw_tag($feature);
    }
  }

  return @{$self->glyphs||[]};
}

sub draw_tag { ## stub }

1;
