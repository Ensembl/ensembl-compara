=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ImageConfig::Vkaryotype;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig::Vertical);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    label           => 'below',
    band_labels     => 'off',
    top_margin      => 5,
    band_links      => 'no',
    all_chromosomes => 'yes',
  });

  $self->add_menus('ideogram', 'user_data');

  $self->add_tracks('ideogram',
    [ 'drag_left', '', 'Vdraggable', { display => 'normal', part => 0, menu => 'no' }],
    [ 'Videogram', 'Ideogram', 'Videogram', {
      display    => 'normal',
      renderers  => [ 'normal', 'normal' ],
      width      => 12,
      totalwidth => 18,
      padding    => 6,
      colourset  => 'ideogram',
      menu       => 'no',
    }],
    [ 'drag_right', '', 'Vdraggable', { display => 'normal', part => 1, menu => 'no' }],
  );
}

1;
