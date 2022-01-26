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

package EnsEMBL::Draw::GlyphSet::age_of_base_legend;

### Draws legend for age of base bigwig track

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::legend);

sub _init {
  my $self     = shift;

  ## Hide if accompanying track is off
  my $node = $self->{'config'}->get_node('age_of_base');
  return if (!$node || $node->get('display') eq 'off');

  $self->init_legend(2);

  my @info = (
              ['Human-specific base', 'red2'],
              ['Appeared in primates (paler = older)', [qw(blue slateblue2 white)]],
              ['Appeared in mammals (paler = older)', [qw(snow4 snow3 white)]],
              );

  foreach (@info) {
    $self->add_to_legend({
      legend    => $_->[0],
      colour    => $_->[1],
      gradient  => {'boxes' => 5, 'labels' => 0}, 
    });
  }

  $self->add_space;
}

1;
