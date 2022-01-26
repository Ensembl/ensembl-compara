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

package EnsEMBL::Web::ImageConfig::lrgsnpview_gene;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    title            => 'MyGenes',
    label_width      => 100,   # width of labels on left-hand side
    opt_halfheight   => 0,     # glyphs are half-height [ probably removed when this becomes a track config ]
    opt_empty_tracks => 0,     # include empty tracks
  });

  $self->create_menus(
    lrg        => 'LRG',
    transcript => 'Other Genes',
    variation  => 'Germline variation',
    somatic    => 'Somatic Mutations',
    other      => 'Other Stuff'
  );

  $self->load_tracks;

  $self->add_tracks('lrg',
    [ 'lrg_transcript', 'LRG', '_lrg_transcript', {
      display     => 'normal',
      name        => 'LRG',
      description => 'Transcripts from the <a class="external" href="http://www.lrg-sequence.org">Locus Reference Genomic sequence</a> project.',
      logic_names => [ 'LRG_import' ],
      logic_name  => 'LRG_import',
      colours     => $self->species_defs->colour('gene'),
      label_key   => '[display_label]',
    }]
  );


  $self->add_tracks('variation',
    [ 'snp_join',         '', 'snp_join',         { display => 'on',     strand => 'b', menu => 'no', tag => 0, colours => $self->species_defs->colour('variation') }],
    [ 'geneexon_bgtrack', '', 'geneexon_bgtrack', { display => 'normal', strand => 'b', menu => 'no', tag => 0, colours => 'bisque', src => 'all' }]
  );

  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'f', menu => 'no' }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'f', menu => 'no', notext => 1 }],
    [ 'spacer',   '', 'spacer',   { display => 'normal', strand => 'r', menu => 'no', height => 50 }]
  );


  $self->modify_configs(
    [ 'transcript', 'transcript_core_ensembl' ],
    { display => 'off' }
  );

  $self->modify_configs(
    [ 'variation' ],
    { menu => 'no' }
  );

  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'normal', strand => 'f' }
  );
}

1;
