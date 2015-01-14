=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::simple_histogram;

### Draws data stored as simple features in a histogram style track
### e.g. if added to web_data as a rendering option

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_wiggle_and_block);

sub draw_features  {
  my ($self, $wiggle) = @_;

  my $features = $self->features;
  return undef unless scalar @{$features};

  my $colour_key             = $self->colour_key($features->[0]);
  my $feature_colour         = $self->my_colour($colour_key);
  my $axis_colour            = $self->my_colour($colour_key, 'join') || 'black';
  my (@sorted_features, $min_score, $max_score); 

  if (scalar @$features >> 1) {
    @sorted_features   = sort { $a->score <=> $b->score  } @$features;
    $min_score = $sorted_features[1]->score;
    $max_score = $sorted_features[-1]->score;
  } else { 
    @sorted_features = @$features;
    $min_score = $sorted_features[0]->score;
    $max_score = $min_score;
  }

  $self->draw_wiggle_plot(\@sorted_features, {
    min_score            => $min_score,
    max_score            => $max_score,
    score_colour         => $feature_colour,
    axis_colour          => $axis_colour,
    axis_label           => 'off',
  });  

  return 0;
}


sub features  {
  my $self = shift;
  my $call     = 'get_all_' . ($self->my_config('type') || 'SimpleFeatures');
  my $db_type       = $self->my_config('db');
  my @features = map @{$self->{'container'}->$call($_, undef, $db_type)||[]}, @{$self->my_config('logic_names')||[]};
  
  return \@features;
}

sub colour_key    { return lc $_[1]->analysis->logic_name; }

1;
