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

package EnsEMBL::Web::ImageConfig::lrgsnpview_context;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    title             => 'Context slice',
    no_labels         => 1, # show track names on left-hand side
    label_width       => 100,   # width of labels on left-hand side
    features          => [],
    opt_halfheight    => 0,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks  => 0,     # include empty tracks..
  });

  $self->create_menus(
    sequence   => 'Sequence',
    transcript => 'Genes',
    variation  => 'Germline variation',
    somatic    => 'Somatic Mutations',
    other      => 'Other'
  );

  $self->add_tracks('sequence',
    [ 'contig', 'Contigs', 'contig', { display => 'normal', strand => 'r' }]
  );

  $self->load_tracks;

  $self->add_tracks('other',
    [ 'geneexon_bgtrack', '', 'geneexon_bgtrack', { display => 'normal', strand => 'b', menu => 'no', tag => 0, colours => 'bisque', src => 'all' }],
    [ 'draggable',        '', 'draggable',        { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'snp_join',         '', 'snp_join',         { display => 'on',     strand => 'r', menu => 'no', tag => 0, colours => $self->species_defs->colour('variation') }],
    [ 'spacer',           '', 'spacer',           { display => 'normal', strand => 'r', menu => 'no' }],
    [ 'ruler',            '', 'ruler',            { display => 'normal', strand => 'f', name => 'Ruler',     description => 'Shows the length of the region being displayed' } }],
    [ 'scalebar',         '', 'scalebar',         { display => 'normal', strand => 'f', name => 'Scale bar', description => 'Shows the scalebar', height => 50 }]
  );

  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'normal' }
  );
}

1;
