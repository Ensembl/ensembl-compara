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

package EnsEMBL::Web::ImageConfig::speciestreeview;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_extra_menus {
  shift->add_extra_menu('display_option');
}

sub init_cacheable {
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    storable          => 0,
    image_resizeable  => 1,
    no_labels         => 1,
    bgcolor           => 'background1',
    bgcolour1         => 'background1',
    bgcolour2         => 'background1',
  });

  $self->create_menus('other');

  $self->add_tracks('other',
    [ 'genetree',        'Gene',   'genetree',        { on => 'on', strand => 'r', menu => 'no'}],
    [ 'genetree_legend', 'Legend', 'genetree_legend', { on => 'on', strand => 'r', menu => 'no'}],
  );
}

1;

