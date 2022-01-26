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

package EnsEMBL::Web::Component::UserData::TrackHubSearch;

### Form for inputting search terms to the track hub registry search API

use strict;
use warnings;
no warnings "uninitialized";

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  1 );
}

sub caption {
  my $self = shift;
  return 'Find a Track Hub';
}

sub content {
  my $self    = shift;
  my $hub     = $self->hub;
  my $sd      = $hub->species_defs;
  my $object  = $self->object;
  my $html;

  ## Compare species available on registry with valid species for this site

  my ($rest_species, $error) = $self->object->thr_fetch('api/info/assemblies');

  if ($error) {
    $html = $self->warning_panel('Oops!', 'Sorry, we are unable to fetch data from the Track Hub Registry at the moment. You may wish to <a href="http://www.trackhubregistry.org/" rel="external">visit the registry</a> directly to search for a hub.');
  }
  else {
    my $message;

    ## Start creating form, as in most cases we need it
    my $form = $self->modal_form('select', $hub->url({'type' => 'UserData', 'action' => 'TrackHubResults'}), {
          'class'             => 'bgcolour',
          'no_button'         => 1
    });
    my $fieldset = $form->add_fieldset({'no_required_notes' => 1});

    ## Are we on a species page or not?
    my $current_species = $hub->species;
    if ($current_species =~ /multi|common/i) {
      $message = '<p>Sorry, we do not allow searching for multiple species. Please go to a species-specific page to find and attach track hubs on this website.</p>';
    }
    else {
      ## Can we find it in the THR json?
      my $sci_name    = $sd->SPECIES_SCIENTIFIC_NAME;
      my $thr_species = $object->thr_ok_species($rest_species, $current_species);

      ## Now display the appropriate content
      if ($thr_species) {
        ## We display the values as used on the Ensembl website
        $fieldset->add_field({
                              'type'    => 'noedit',
                              'label'   => 'Species',
                              'name'    => 'species_display',
                              'value'   => $sd->species_label($current_species, 1),
        });
        $fieldset->add_field({
                              'type'    => 'noedit',
                              'label'   => 'Assembly',
                              'name'    => 'assembly_display',
                              'value'   => $sd->ASSEMBLY_VERSION,
        });
        $form->add_hidden({'name' => 'display_name',   'value' => $sd->SPECIES_DISPLAY_NAME});
        ## But these are the 'real' values we want to use for the THR search
        $form->add_hidden({'name' => 'thr_species',   'value' => $thr_species->{'thr_name'}});
        $form->add_hidden({'name' => 'assembly_id',   'value' => $thr_species->{'assembly_id'}});
        $form->add_hidden({'name' => 'assembly_key',  'value' => $thr_species->{'assembly_key'}});
      }
      else {
        $message = '<p>Sorry, the Track Hub Registry currently has no trackhubs compatible with this species and assembly.</p>';
      }
    }

    if ($message) {
      $html .= $message;
      $html .= sprintf('<p>You can search the <a href="%s">Track Hub Registry website</a> for the full range of publicly available data.</p>', $sd->TRACKHUB_REGISTRY_URL);
    }
    else {
      ## Add remaining fields and show form
      my @data_types = qw(genomics transcriptomics proteomics);
      my $values     = [{'value' => '', 'caption' => '-- all --'}];
      push @$values, {'value' => $_, 'caption' => $_} for @data_types;
      $fieldset->add_field({
                            'type'          => 'dropdown',
                            'name'          => 'data_type',
                            'label'         => 'Data type',
                            'values'        => $values,
                            'value'         => $hub->param('data_type') || '',
      });

      $fieldset->add_field({
                            'type'          => 'String',
                            'name'          => 'query',
                            'label'         => 'Text search',
                            'value'         => $hub->param('query') || '',
                            'notes'         => 'Hint: Leave "text search" empty to show all track hubs for this species',
      });

      $fieldset->add_button({
                            'type'          => 'Submit',
                            'name'          => 'submit_button',
                            'value'         => 'Search'
      });

      $html .= $form->render;
    }
  }

  return sprintf '<input type="hidden" class="subpanel_type" value="UserData" /><h2>Search the Track Hub Registry</h2>%s', $html;

}

1;
