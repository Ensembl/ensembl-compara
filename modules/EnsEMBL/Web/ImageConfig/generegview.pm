=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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
  my $hub  = $self->hub;

  $self->SUPER::init_cacheable(@_);

  $self->set_parameters({
    image_resizeable  => 1,
    sortable_tracks   => 'drag',  # allow the user to reorder tracks
    opt_lines         => 1,  # draw registry lines
  });

  $self->create_menus(qw(
    transcript
    prediction
    functional
    other
    information
  ));

  $self->load_tracks;

  my $eqtl_rest_url = $hub->species_defs->EQTL_REST_URL;
  my $rest = EnsEMBL::Web::REST->new($hub);
  my $fetch_url = sprintf( "%sqtl_groups?size=1000", $eqtl_rest_url);

  my ($response,$error) = $rest->fetch_url($fetch_url, {});

  my @qtl_groups = @{$response->{'_embedded'}->{'qtl_groups'}};
  
  my @gtex_tissues;
  foreach my $group (@qtl_groups){
     push @gtex_tissues, $group->{'qtl_group'};
  }

  my $gtex_tissue_example = "Whole_Blood";
  unless(any { $_ eq $gtex_tissue_example } @gtex_tissues) {
    $gtex_tissue_example = $gtex_tissues[0];
  }

  my $menu = $self->get_node('functional');
  my $other_node = $self->get_node('functional_other_regulatory_regions');
  $menu->insert_before($self->create_menu_node('functional_gene_expression','Gene Expression correlations'),$other_node);

  foreach my $tissue (sort @gtex_tissues) {
    my $tissue_readable = $tissue;
    $tissue_readable =~ s/_/ /g;
    my $manplot_desc = qq(
      Complete set of eQTL correlation statistics as computed on $tissue_readable samples. Provided to Ensembl by the EBI eQTL catalog (<a href="https://www.ebi.ac.uk/eqtl" target="_blank">www.ebi.ac.uk/eqtl</a>)
    );
    $self->add_track('functional_gene_expression',"reg_manplot_$tissue","$tissue_readable eQTLs",'reg_manplot',{
      tissue => $tissue,
      display => ($tissue eq $gtex_tissue_example)?'normal':'off',
      strand => 'r',
      colours     => $self->species_defs->colour('variation'),
      description => $manplot_desc,
      renderers => [
        'off',              'Off',
        'pvalue',           'p-value',
        'beta',             'beta',
      ]
    });
  }

  $self->add_tracks('other',
    [ 'ruler',     '',  'ruler',     { display => 'normal', strand => 'r', name => 'Ruler', description => 'Shows the length of the region being displayed' }],
    [ 'draggable', '',  'draggable', { display => 'normal', strand => 'b', menu => 'no' }],
    [ 'scalebar',  '',  'scalebar',  { display => 'normal', strand => 'b', name => 'Scale bar', description => 'Shows the scalebar', height => 50 }],
    [ 'variation_legend',     '', 'variation_legend',     { display => 'on',  strand => 'r', menu => 'no', caption => 'Variant Legend'                                                              }],
  );

# Uncomment if variation track needs to be enable again (ENSWEB-2955) and dont forget to add variation in the main create_menu
#  $self->modify_configs(
#    [ 'regbuild', 'variation_set_ph_variants' ],
#    { display => 'normal' }
#  );

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

#  $_->remove for grep $_->id ne 'variation_set_ph_variants', grep $_->get_data('node_type') eq 'track', @{$self->tree->get_node('variation')->get_all_nodes}; #only showing one track for variation; uncomment to bring it back

}

1;
