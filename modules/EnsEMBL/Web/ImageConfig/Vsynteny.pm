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

package EnsEMBL::Web::ImageConfig::Vsynteny;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig::Vertical);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    storable        => 0,
    bottom_toolbar  => 1,
    label           => 'above',
    band_labels     => 'off',
    image_height    => 500,
    image_width     => 550,
    top_margin      => 20,
    band_links      => 'no',
    main_width      => 30,
    secondary_width => 12,
    padding         => 4,
    spacing         => 20,
    inner_padding   => 140,
    outer_padding   => 20,
  });

  $self->create_menus('synteny');
  $self->add_tracks('synteny', [ 'Vsynteny', 'Videogram', 'Vsynteny', { display => 'normal', renderers => [ 'normal', 'normal' ], colourset => 'ideogram' } ]);
}

sub init_non_cacheable {
  ## @override
  ## Nothing non cacheable
}

1;
