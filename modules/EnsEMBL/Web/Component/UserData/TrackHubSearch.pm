=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
    $html = $self->warning_panel('Oops!', 'Sorry, we are unable to fetch data from the Track Hub Registry at the moment');

    ## Show internally configured list
    $html .= $self->_show_configured_hubs;
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

    if (keys %$ok_species) {
      my $current_species = $hub->data_species;

      my $form = $self->modal_form('select', $hub->url({'type' => 'UserData', 'action' => 'TrackHubResults'}), {
          'class'             => 'check',
          'no_button'         => 1
      });

      my $fieldset = $form->add_fieldset({'no_required_notes' => 1});

      # Create a data structure for species, with display labels and their current assemblies
      my @species = sort {$a->{'caption'} cmp $b->{'caption'}} map({'value' => $_, 'caption' => $sd->species_label($_, 1), 'assembly' => $sd->get_config($_, 'ASSEMBLY_VERSION')}, keys %$ok_species);

      # Create HTML for showing/hiding assembly names to work with JS
      my $assembly_names = join '', map { sprintf '<span class="_stt_%s">%s</span>', $_->{'value'}, delete $_->{'assembly'} } @species;

      $fieldset->add_field({
                            'type'          => 'dropdown',
                            'name'          => 'species',
                            'label'         => 'Species',
                            'values'        => \@species,
                            'value'         => $current_species,
                            'class'         => '_stt'
      });

      $fieldset->add_field({
                            'type'          => 'noedit',
                            'label'         => 'Assembly',
                            'name'          => 'assembly_name',
                            'value'         => $assembly_names,
                            'no_input'      => 1,
                            'is_html'       => 1,
      });

      my @data_types = qw(genomics transcriptomics proteomics);
      my $values     = [{'value' => '', 'caption' => '-- all --'}];
      push @$values, {'value' => $_, 'caption' => $_} for @data_types;
      $fieldset->add_field({
                            'type'          => 'dropdown',
                            'name'          => 'type',
                            'label'         => 'Data type',
                            'values'        => $values,
                            'value'         => $hub->param('type') || '',
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
    else {
      $html .= '<p>Sorry, the Track Hub Registry currently has no species compatible with this website.</p>';
      $html .= sprintf('<p>Please visit the <a href="%s">Track Hub Registry website</a> for more information.</p>', $rest->server);
    }
  }

  return sprintf '<input type="hidden" class="subpanel_type" value="UserData" /><h2>Search the Track Hub Registry</h2>%s', $html;

}

sub _show_configured_hubs {
    my $self          = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;

  ## Get current Ensembl species
  my $species   = $hub->species;
  my $assembly  = $species_defs->ASSEMBLY_VERSION;

  my $trackhubs = [];
  my $imageconfig   = $hub->get_imageconfig('contigviewbottom');

  ## This is all a bit hacky, but makes configuration of multi-species trackhubs simpler
  my %sp_hubs = (%{$species_defs->PUBLIC_TRACKHUBS||{}}, $species_defs->multiX('PUBLIC_MULTISPECIES_TRACKHUBS'));

  ## Get hub information
  if (keys %sp_hubs) {
    while (my($key,$menu) = each (%sp_hubs)) {
      ## multiX returns a hash, not a hash ref, and Perl gets confused
      ## if you try to assign hashes and hashrefs to same variable
      my %multi = $species_defs->multiX($key);
      my %config = keys %multi ? %multi : %{$species_defs->get_config($species, $key)||{}};
      next unless keys %config;

      my $trackhub;
      my %assemblies;
      if ($config{'assemblies'}) {
        %assemblies = @{$config{'assemblies'}};
      }
      else {
        foreach (@{$config{'assembly'}}) {
          $assemblies{$_} = 1;
        }
      }
      next unless $assemblies{$assembly};

      $config{'priority'} = 0 unless $config{'priority'};
      $trackhub = {'menu' => $menu, %config};

      push @$trackhubs, $trackhub;
    }
  }

  return unless scalar @$trackhubs;

  my $common_name = $species_defs->SPECIES_COMMON_NAME;

  my $html = "<p>We maintain the following static list of popular hubs for $common_name assembly $assembly, but cannot guarantee they will be online:</p>";

  $html .= '<ul>';

  foreach my $hub_info (@$trackhubs) {

    my $location = $species_defs->get_config($species, 'SAMPLE_DATA')->{'LOCATION_PARAM'};
    my $link = sprintf('<a href="/%s/Location/View?r=%s;contigviewbottom=url:%s;format=TRACKHUB;menu=%s#modal_user_data">%s</a>',
                         $species, $location,
                         $hub_info->{'url'}, $hub_info->{'menu'}, $hub_info->{'name'}
                        );

    $html .= sprintf '<li>%s: %s</li>', $link, $hub_info->{'description'};
  }

  $html .= '</ul>';
  
  if ($species eq 'Homo_sapiens' && $assembly eq 'GRCh37') {
    $html .= '<p>Track hubs for Human GRCh37 can be found on our <a href="http://grch37.ensembl.org">archive site</a>.</p>';
  }

  return $html; 
}

1;
