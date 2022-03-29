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

package EnsEMBL::Web::Configuration::Info;

use strict;

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Utils::FormatText qw(pluralise);

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'Index';
}

sub default_template { return 'Legacy::Wide'; }

sub short_caption { return 'About this species'; }

sub availability {
  my $self = shift;
  my $hash = $self->get_availability;
  $hash->{'database.variation'} = exists $self->hub->species_defs->databases->{'DATABASE_VARIATION'} ? 1 : 0;
  return $hash;
}

sub modify_page_elements {
  my $self = shift;
  my $page = $self->page;
  $page->remove_body_element('summary');
}

sub populate_tree {
  my $self           = shift;
  my $species_defs   = $self->hub->species_defs;
  my %error_messages = EnsEMBL::Web::Constants::ERROR_MESSAGES;

  my $index = $self->create_node('Index', '', [qw(homepage EnsEMBL::Web::Component::Info::HomePage)], {});

  $self->create_node('Annotation', '',
    [qw(blurb EnsEMBL::Web::Component::Info::SpeciesBlurb)]
  );

  my $has_strains = $species_defs->ALL_STRAINS;
  if ($has_strains) {
    my $strain_term   = $species_defs->STRAIN_TYPE || 'strain';
    my $strain_title  = pluralise(ucfirst $species_defs->STRAIN_TYPE);
    my $lookup        = $species_defs->prodnames_to_urls_lookup;

    ## Redirect strains to the strain page for the parent species 
    ## as long as we're not on the parent species
    if ( $self->hub->action ne 'Strains' && $self->hub->action ne $strain_title 
        && $species_defs->STRAIN_GROUP && !$species_defs->IS_REFERENCE) {
      my $url = $self->hub->url({'species' => $lookup->{$species_defs->STRAIN_GROUP}, 'action' => $strain_title});
      $self->hub->redirect($url);
    }

    $self->create_node($strain_title, '',
        [$strain_term, 'EnsEMBL::Web::Component::Info::Strains']
    );
    if ($strain_term ne 'strain') {
      ## Fallback node to avoid broken links
      $self->create_node('Strains', '',
        [qw(blurb EnsEMBL::Web::Component::Info::Strains)],
        { no_menu_entry => 1 }
      );
    }
  }

  $index->append_child($self->create_subnode('Error', 'Unknown error',
    [qw(error EnsEMBL::Web::Component::Info::SpeciesBurp)],
    { no_menu_entry => 1 }
  ));
  
  foreach (keys %error_messages) {
    $index->append_child($self->create_subnode("Error/$_", "Error $_",
      [qw(error EnsEMBL::Web::Component::Info::SpeciesBurp)],
      { no_menu_entry => 1 }
    ));
  }

  $self->create_node('GeneGallery', '',
      [qw(gene_gallery EnsEMBL::Web::Component::Info::GeneGallery)],
      { 'availability' => 1, 'template' => 'Legacy::Static' }
  );
  $self->create_node('VariationGallery', '',
      [qw(var_gallery EnsEMBL::Web::Component::Info::VariationGallery)],
      { 'availability' => 'database:variation', 'template' => 'Legacy::Static' }
  );
  $self->create_node('LocationGallery', '',
      [qw(loc_gallery EnsEMBL::Web::Component::Info::LocationGallery)],
      { 'availability' => 1, 'template' => 'Legacy::Static' }
  );
  $self->create_node('CheckGallery', '', [],
      { command => 'EnsEMBL::Web::Command::Info::CheckGallery', no_menu_entry => 1 }
  );

  $self->create_node('Expression', 'Gene Expression',
    [qw(
      rnaseq_table  EnsEMBL::Web::Component::Info::ExpressionTable
    )],
    { 'availability' => 'database:rnaseq' }
  );

  $self->create_node('WhatsNew', '',
    [qw(whatsnew EnsEMBL::Web::Component::Info::WhatsNew)]
  );

  ## Generic node for including arbitrary HTML files about a species
  $self->create_node('Content', '',
    [qw(content EnsEMBL::Web::Component::Info::Content)]
  );
}

1;
