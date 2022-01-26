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

package EnsEMBL::Web::ImageConfig::gene_splice;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    sortable_tracks => 'drag',  # allow the user to reorder tracks
    label_width      => 100, # width of labels on left-hand side
    opt_halfheight   => 0,   # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks => 0,   # include empty tracks..
  });

  $self->create_menus(qw(
    transcript
    gsv_transcript
    other
    gsv_domain
  ));

  $self->load_tracks;

  $self->get_node('transcript')->set_data('caption', 'Other genes');

  $self->modify_configs(
    [ 'gsv_transcript', 'other' ],
    { menu => 'no' }
  );

  if ($self->cache_code ne $self->type) {
    my $func = "init_".$self->cache_code;
    $self->$func if $self->can($func);
  }
}

sub init_gene {
  my $self = shift;

  $self->add_tracks('other',
    [ 'geneexon_bgtrack', '', 'geneexon_bgtrack', { display => 'normal', strand => 'b', menu => 'no', tag => 0, colours => 'bisque', src => 'all' }]
  );

  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'f', menu => 'no'               }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'f', menu => 'no', notext => 1  }],
    [ 'spacer',   '', 'spacer',   { display => 'normal', strand => 'r', menu => 'no', height => 52 }],
  );

  $self->get_node('gsv_domain')->remove;
}

sub init_transcript {
  my $self = shift;

  $self->get_node('transcript')->remove;

  $self->add_tracks('other',
    [ 'spacer', '', 'spacer', { display => 'normal', strand => 'r', menu => 'no', height => 10 }],
  );
}

1;
