=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::HTML::GalleryHome;

### Simple form providing an entry to the new Site Gallery navigation system 

use strict;
use warnings;

use EnsEMBL::Web::Form;
use EnsEMBL::Web::Component;

use JSON qw(to_json);

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self  = shift;
  my $hub   = $self->hub;
  my $html;

  my ($species, $sample_data) = $self->_species_data;

  ## Check session for messages
  my $error = $hub->session->get_record_data({'type' => 'message', 'code' => 'gallery'});

  if ($error && $error->{'message'}) {
    $html .= '<div style="width:95%" class="warning"><h3>Error</h3><div class="message-pad"><p>'.$error->{'message'}.'</p></div></div>';
    $self->hub->session->delete_records({'type' => 'message', 'code' => 'gallery'});
  }

  $html .= '<div class="js_panel" id="site-gallery-home">
      <input type="hidden" class="panel_type" value="SiteGalleryHome">';

  my $form  = EnsEMBL::Web::Form->new({'id' => 'gallery_home', 'action' => $hub->url({qw(species Multi type Info action CheckGallery)}), 'name' => 'gallery_home'});
  my $default_species = $hub->param('species') || $hub->species_defs->ENSEMBL_PRIMARY_SPECIES || $species->[0]->{'value'};

  # species dropdown
  $form->add_field({
    'label'         => 'Species',
    'type'          => 'dropdown',
    'name'          => 'species',
    'value'         => $default_species,
    'values'        => \@$species
  });

  # data type field
  $form->add_field({
    'type'        => 'Radiolist',
    'name'        => 'data_type',
    'label'       => 'Feature type',
    'value'       => 'variation',
    'values'      => [
                        {'value' => 'gene',       'caption' => 'Genes'            },
                        {'value' => 'location',   'caption' => 'Genomic locations'},
                        {'value' => 'variation',  'caption' => 'Variants'         }
                     ]
  });

  # hidden sample data used by js
  $form->add_hidden({'class' => 'js_param json', 'name' => 'sample_data', 'value' => to_json($sample_data)});

  $form->add_field({
    'type'  => 'String',
    'name'  => 'identifier',
    'label' => 'Identifier',
  });

  $form->add_button({
    'name'  => 'submit',
    'value' => 'Go',
    'class' => 'submit'
  });

  $html .= $form->render;

  $html .= '</div>';

  return $html; 
}

sub _species_data {
  ## @private
  my $self = shift;

  if (!$self->{'_species'} || !$self->{'_sample_data'}) {
    my $hub     = $self->hub;
    my $sd      = $hub->species_defs;
    my %fav     = map { $_ => 1 } @{$hub->get_favourite_species};

    my @species;
    my %sample_data;

    foreach my $species ($sd->valid_species) {

      push @species, { 'value' => $species, 'caption' => $sd->get_config($species, 'SPECIES_COMMON_NAME') };

      my $data = $sd->get_config($species, 'SAMPLE_DATA');

      for (qw(gene location variation)) {
        my $value = $data->{uc $_.'_PARAM'};
        $sample_data{$species}{$_} = $value if $value;
      }
    }

    @species = sort { ($a->{'favourite'} xor $b->{'favourite'}) ? $b->{'favourite'} || -1 : $a->{'caption'} cmp $b->{'caption'} } @species;

    $self->{'_species'}     = \@species;
    $self->{'_sample_data'} = \%sample_data;
  }

  return ($self->{'_species'}, $self->{'_sample_data'});
}

1;
