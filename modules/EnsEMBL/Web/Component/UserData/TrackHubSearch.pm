=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return 'Find a Track Hub';
}

sub content {
  my $self            = shift;
  my $hub             = $self->hub;
  my $sd              = $hub->species_defs;
  my $sitename        = $sd->ENSEMBL_SITETYPE;
  my $current_species = $hub->data_species;

  ## REST call
  my $rest = EnsEMBL::Web::REST->new($hub, $sd->TRACKHUB_REGISTRY_URL);
  return unless $rest;

  ## Compare species available on registry with valid species for this site
  my %local_species = map {$_ => 1} $sd->valid_species;

  my $endpoint = '/api/info/species';
  
  my $rest_species = $rest->fetch($endpoint);
  my $ok_species   = {};

  foreach (@{$rest_species||[]}) {
    (my $species = $_) =~ s/ /_/;
    #warn ">>> SPECIES $species";
    if ($local_species{$species}) {
      $ok_species->{$species} = 1;
    }
  }

  my $html;
  
  if (keys %$ok_species) {
    my $form            = $self->modal_form('select', $hub->url({'type' => 'UserData', 'action' => 'QueryTrackHub'}), {
      'skip_validation'   => 1, # default JS validation is skipped as this form goes through a customised validation
      'class'             => 'check',
      'no_button'         => 1
    });

    my $fieldset = $form->add_fieldset({'no_required_notes' => 1});

    $html .= $form->render;
  }
  else {
    $html .= '<p>Sorry, the Track Hub Registry has no species compatible with this website.</p>';
    $html .= sprintf('<p>Please visit the <a href="%s">Track Hub Registry website</a> for more information.</p>', $rest->server);
  }

  return sprintf '<input type="hidden" class="subpanel_type" value="UserData" /><h2>Search the Track Hub Registry</h2>%s', $html;

=pod
  # Create a data structure for species, with display labels and their current assemblies
  my @species = sort {$a->{'caption'} cmp $b->{'caption'}} map({'value' => $_, 'caption' => $sd->species_label($_, 1), 'assembly' => $sd->get_config($_, 'ASSEMBLY_VERSION')}, $sd->valid_species);

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

  $fieldset->add_field({
    'label'         => 'Data',
    'field_class'   => '_userdata_add',
    'elements'      => [{
      'type'          => 'Text',
      'value'         => 'Paste in data or provide a file URL',
      'name'          => 'text',
      'class'         => 'inactive'
    }, {
      'type'          => 'noedit',
      'value'         => "Or upload file (max $max_upload_size)",
      'no_input'      => 1,
      'element_class' => 'inline-label'
    }, {
      'type'          => 'File',
      'name'          => 'file',
    }]
  });

  $self->add_auto_format_dropdown($form);

  $fieldset->add_button({
    'type'          => 'Submit',
    'name'          => 'submit_button',
    'value'         => 'Add data'
  });

=cut

}

1;
