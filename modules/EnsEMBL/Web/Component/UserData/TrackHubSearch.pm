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

package EnsEMBL::Web::Component::UserData::TrackHubSearch;

### Form for inputting search terms to the track hub registry search API

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::REST;

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
  my $self            = shift;
  my $hub             = $self->hub;
  my $sd              = $hub->species_defs;
  my $html;

  ## REST call
  my $rest = EnsEMBL::Web::REST->new($hub, $sd->TRACKHUB_REGISTRY_URL);
  return unless $rest;

  ## Compare species available on registry with valid species for this site
  my %local_species = map {$_ => 1} $sd->valid_species;

  my $endpoint = 'api/info/assemblies';
  
  my ($rest_species, $error) = $rest->fetch($endpoint);

  if ($error) {
    $html = $self->warning_panel('Oops!', 'Sorry, we are unable to fetch data from the Track Hub Registry at the moment. You may wish to <a href="http://www.trackhubregistry.org/" rel="external">visit the registry</a> directly to search for a hub.');
  }
  else {
    my $ok_species   = {};

    foreach (keys %{$rest_species||[]}) {
      (my $species = $_) =~ s/ /_/;
      if ($local_species{$species}) {
        my $gca = $sd->get_config($species, 'ASSEMBLY_ACCESSION');
        if (grep $gca, @{$rest_species->{$_}||[]}) {
          $ok_species->{$species} = $_;
        }
      }
    }

    my ($form, $fieldset, $message);

    ## Do we have usable data?
    if (keys %$ok_species) {
      ## Are we on a species page? If not, show all available species
      my $current_species = $hub->species;

      ## Start creating form, as in most cases we need it
      $form = $self->modal_form('select', $hub->url({'type' => 'UserData', 'action' => 'TrackHubResults'}), {
            'class'             => 'check',
            'no_button'         => 1
      });
      $fieldset = $form->add_fieldset({'no_required_notes' => 1});

      if ($current_species =~ /multi|common/i) {
        # Create a data structure for species, with display labels and their current assemblies
        my @species = sort {$a->{'caption'} cmp $b->{'caption'}} map({'value' => $_, 'caption' => $sd->species_label($_, 1), 'assembly' => $sd->get_config($_, 'ASSEMBLY_VERSION')}, keys %$ok_species);

        ## Show dropdown of all available species
        $fieldset->add_field({
                            'type'          => 'dropdown',
                            'name'          => 'species',
                            'label'         => 'Species',
                            'values'        => \@species,
                            'value'         => $current_species,
                            'class'         => '_stt'
        });

        # Create HTML for showing/hiding assembly names to work with JS
        my $assembly_names = join '', map { sprintf '<span class="_stt_%s">%s</span>', $_->{'value'}, delete $_->{'assembly'} } @species;
        $fieldset->add_field({
                            'type'          => 'noedit',
                            'label'         => 'Assembly',
                            'name'          => 'assembly_name',
                            'value'         => $assembly_names,
                            'no_input'      => 1,
                            'is_html'       => 1,
        });
      }
      else {
        ## Is this species available in the registry?
        if ($ok_species->{$current_species}) {

          ## Only display current species and assembly
          $fieldset->add_field({
                              'type'    => 'noedit',
                              'label'   => 'Species',
                              'name'    => 'species_display',
                              'value'   => $sd->species_label($current_species, 1),
          });
          $form->add_hidden({'name' => 'species', 'value' => $current_species});

          $fieldset->add_field({
                              'type'    => 'noedit',
                              'label'   => 'Assembly',
                              'name'    => 'assembly_display',
                              'value'   => $sd->ASSEMBLY_VERSION,
          });
          $form->add_hidden({'name' => 'assembly_name', 'value' => $sd->ASSEMBLY_VERSION});
        }
        else {
          $message = '<p>Sorry, the Track Hub Registry currently has no trackhubs compatible with this species.</p>';
        }
      }
    }
    else {
      $message = '<p>Sorry, the Track Hub Registry currently has no species compatible with this website.</p>';
    }

    if ($message) {
      $html .= $message;
      $html .= sprintf('<p>Please visit the <a href="%s">Track Hub Registry website</a> for more information.</p>', $rest->server);
    }
    else {
      ## Add remaining fields
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
