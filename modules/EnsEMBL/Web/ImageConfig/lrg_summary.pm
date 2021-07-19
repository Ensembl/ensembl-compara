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

package EnsEMBL::Web::ImageConfig::lrg_summary;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    sortable_tracks => 'drag',  # allow the user to reorder tracks
    opt_lines => 1,  # draw registry lines
    opt_empty_tracks => 1,     # include empty tracks
  });

  $self->create_menus(qw(
    sequence
    transcript
    prediction
    lrg
    variation
    somatic
    functional
    external_data
    user_data
    information
  ));

  $self->get_node('transcript')->set_data('caption', 'Other genes');

  $self->add_tracks('information',
    [ 'scalebar',  '', 'lrg_scalebar', { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar' }],
    [ 'draggable', '', 'draggable',    { display => 'normal', strand => 'b', menu => 'no' }],
  );

  $self->load_tracks;

  $self->add_tracks('lrg',
    [ 'lrg_transcript', 'LRG transcripts', '_transcript', {
      display     => 'transcript_label',
      strand      => 'b',
      name        => 'LRG transcripts',
      description => 'Transcripts from the <a class="external" href="http://www.lrg-sequence.org">Locus Reference Genomic sequence</a> project.',
      logic_names => [ 'LRG_import' ],
      logic_name  => 'LRG_import',
      colours     => $self->species_defs->colour('gene'),
      label_key   => '[display_label]',
      colour_key  => '[logic_name]',
      zmenu       => 'LRG',
    }],
    [ 'lrg_band', 'LRG gene', 'lrg_band', {
      display     => 'normal',
      strand      => 'f',
      name        => 'LRG gene',
      description => 'Track showing the underlying LRG gene from the <a class="external" href="http://www.lrg-sequence.org">Locus Reference Genomic sequence</a> project.',
      colours     => $self->species_defs->colour('gene'),
      zmenu       => 'LRG',
    }]
  );

  $self->modify_configs(['transcript'], { strand => 'b'});

  $self->modify_configs(
    [ 'fg_regulatory_features_funcgen', 'transcript', 'prediction', 'variation' ],
    { display => 'off' }
  );

  $self->modify_configs(
    [ 'reg_feats_MultiCell' ],
    { display => 'normal' }
  );

  $self->modify_configs(
    [ 'transcript_otherfeatures_refseq_human_import', 'transcript_core_ensembl' ],
    { display => 'transcript_label' }
  );
}

1;
