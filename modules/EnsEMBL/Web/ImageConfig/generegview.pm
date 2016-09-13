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

package EnsEMBL::Web::ImageConfig::generegview;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

use List::MoreUtils qw(any);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    image_resizeable  => 1,
    sortable_tracks   => 'drag',  # allow the user to reorder tracks
    opt_lines         => 1,  # draw registry lines
  });

  $self->create_menus(qw(
    transcript
    prediction
    variation
    functional
    other
    information
  ));

  $self->load_tracks;

  my $gencode_version = $self->hub->species_defs->GENCODE_VERSION ? $self->hub->species_defs->GENCODE_VERSION : '';
  $self->add_track('transcript', 'gencode', "Basic Gene Annotations from $gencode_version", '_gencode', {
    labelcaption => "Genes (Basic set from $gencode_version)",
    display     => 'off',
    description => 'The GENCODE set is the gene set for human and mouse. GENCODE Basic is a subset of representative transcripts (splice variants).',
    sortable    => 1,
    colours     => $self->species_defs->colour('gene'),
    label_key  => '[biotype]',
    logic_names => ['proj_ensembl',  'proj_ncrna', 'proj_havana_ig_gene', 'havana_ig_gene', 'ensembl_havana_ig_gene', 'proj_ensembl_havana_lincrna', 'proj_havana', 'ensembl', 'mt_genbank_import', 'ensembl_havana_lincrna', 'proj_ensembl_havana_ig_gene', 'ncrna', 'assembly_patch_ensembl', 'ensembl_havana_gene', 'ensembl_lincrna', 'proj_ensembl_havana_gene', 'havana'],
    renderers   =>  [
      'off',                     'Off',
      'gene_nolabel',            'No exon structure without labels',
      'gene_label',              'No exon structure with labels',
      'transcript_nolabel',      'Expanded without labels',
      'transcript_label',        'Expanded with labels',
      'collapsed_nolabel',       'Collapsed without labels',
      'collapsed_label',         'Collapsed with labels',
      'transcript_label_coding', 'Coding transcripts only (in coding genes)',
    ],
  }) if($gencode_version);

  my @gtex_tissues = sort keys %{$self->hub->species_defs->REST_gtex_tissues||{}};

  my $gtex_tissue_example = "Whole_Blood";
  unless(any { $_ eq $gtex_tissue_example } @gtex_tissues) {
    $gtex_tissue_example = $gtex_tissues[0];
  }

  # Should really come from REST server.
  foreach my $tissue (sort @gtex_tissues) {
    my $tissue_readable = $tissue;
    $tissue_readable =~ s/_/ /g;
    my $manplot_desc = qq(
      Complete set of eQTL correlation statistics as computed by the GTEx consortium on $tissue_readable samples.
      The GTEx Consortium. Science. 8 May 2015: Vol 348 no. 6235 pp 648-660. DOI: 10.1126/science. PMID: 1262110.
    );
    $self->add_track('functional_other_regulatory_regions',"reg_manplot_$tissue","$tissue_readable GTEX eQTLs",'reg_manplot',{
      tissue => $tissue,
      display => ($tissue eq $gtex_tissue_example)?'normal':'off',
      strand => 'r',
      colours     => $self->species_defs->colour('variation'),
      description => $manplot_desc,
    });
  }

  $self->add_tracks('other',
    [ 'ruler',     '',  'ruler',     { display => 'normal', strand => 'r', name => 'Ruler', description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '',  'draggable', { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'scalebar',  '',  'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar', height => 50 }],
    [ 'variation_legend',     '', 'variation_legend',     { display => 'on',  strand => 'r', menu => 'no', caption => 'Variant Legend'                                                              }],
  );

  $self->modify_configs(
    [ 'regbuild', 'variation_set_ph_variants' ],
    { display => 'normal' }
  );

  $self->modify_configs(
    [ 'regulatory_features_core', 'regulatory_features_non_core' ],
    { display => 'off', menu => 'no' }
  );

  # hack to stop zmenus having the URL ZMenu/Transcript/Regulation, since this causes a ZMenu::Regulation to be created instead of a ZMenu::Transcript
  $_->data->{'zmenu'} ||= 'x' for $self->get_node('transcript')->nodes;

  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'collapsed_label' }
  );

  $self->modify_configs(
    [ 'regulatory_regions_funcgen_feature_set' ],
    { depth => 25, height => 6 }
  );

  $_->remove for grep $_->id ne 'variation_set_ph_variants', grep $_->get_data('node_type') eq 'track', @{$self->tree->get_node('variation')->get_all_nodes}; #only showing one track for variation

}

1;
