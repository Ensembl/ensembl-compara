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

package EnsEMBL::Web::ImageConfig::single_transcript;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    no_labels => 1,
    storable  => 0,
  });

  $self->create_menus('transcript', 'prediction', 'other');

  $self->add_tracks('other',
    [ 'ruler',     '', 'ruler',     { display => 'normal', strand => 'r', name => 'Ruler' }],
    [ 'draggable', '', 'draggable', { display => 'normal', strand => 'b', menu => 'no'    }],
  );

  $self->load_tracks;

  $self->modify_configs(
    [ 'transcript', 'prediction' ],
    { display => 'off', height => 32, non_coding_scale => 0.5 }
  );
}

1;
