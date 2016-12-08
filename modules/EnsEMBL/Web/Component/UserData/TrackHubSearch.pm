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

    ## This next bit of logic is a bit horrible, because EG doesn't always have 
    ## straightforward mappings from its species names to those in the THR

    ## Are we on a species page or not?
    my $current_species = $hub->species;
    if ($current_species =~ /multi|common/i) {
      ## Try to map all the available species from this site
      my $ok_species = $self->_get_ok_species($rest_species, [$self->hub->species_defs->valid_species]);

      ## Create a data structure for species, with display labels and their current assemblies
      my @species = sort {$a->{'caption'} cmp $b->{'caption'}} map({'value' => $_, 'caption' => $sd->species_label($_, 1), 'assembly' => $sd->get_config($_, 'ASSEMBLY_VERSION')}, keys %$ok_species);

      ## Show dropdown of all available species
      $fieldset->add_field({
                            'type'          => 'dropdown',
                            'name'          => 'species',
                            'label'         => 'Species',
                            'values'        => \@species,
                            'class'         => '_stt'
      });

      ## Create HTML for showing/hiding assembly names to work with JS
      my $assembly_names = join '', map { sprintf '<span class="_stt_%s">%s</span>', $_->{'value'}, delete $_->{'assembly'} } @species;
      $fieldset->add_field({
                            'type'          => 'noedit',
                            'label'         => 'Assembly',
                            'name'          => 'assembly',
                            'value'         => $assembly_names,
                            'no_input'      => 1,
                            'is_html'       => 1,
      });
    }
    else {
      ## Can we find it in the THR json?
      my $sci_name    = $hub->species_defs->SPECIES_SCIENTIFIC_NAME;
      my $thr_species = $rest_species->{$sci_name};
      unless ($thr_species) {
        ## Not found, so look for a matching accession id
        my $ok_species = $self->_get_ok_species($rest_species, [$current_species]);
        $thr_species   = $ok_species->{$current_species};
      }

      ## Now display the appropriate content
      if ($thr_species) {
        ## Only display current species and assembly
        $fieldset->add_field({
                              'type'    => 'noedit',
                              'label'   => 'Species',
                              'name'    => 'species_display',
                              'value'   => $sd->species_label($current_species, 1),
        });
        ## Used for display only, not in search
        $form->add_hidden({'name' => 'common_name', 'value' => $sd->SPECIES_COMMON_NAME});
        $fieldset->add_field({
                              'type'    => 'noedit',
                              'label'   => 'Assembly',
                              'name'    => 'assembly_display',
                              'value'   => $sd->ASSEMBLY_VERSION,
        });
        my $assembly_param  = $hub->species_defs->THR_ASSEMBLY_PARAM || 'ASSEMBLY_ACCESSION';
        my $assembly        = $hub->species_defs->get_config($current_species, $assembly_param);
        my $key             = $assembly_param eq 'ASSEMBLY_ACCESSION' ? 'accession' : 'assembly';
        $form->add_hidden({'name' => 'assembly', 'value' => $key.':'.$assembly});
      }
      else {
        $message = '<p>Sorry, the Track Hub Registry currently has no trackhubs compatible with this species and assembly.</p>';
      }
    }

    if ($message) {
      $html .= $message;
      $html .= sprintf('<p>Please visit the <a href="%s">Track Hub Registry website</a> for more information.</p>', $sd->TRACKHUB_REGISTRY_UR);
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


sub _get_ok_species {
## Check a roster of species against the ones in the THR
  my ($self, $thr_species, $local_species) = @_;
  my $hub = $self->hub;
  my $ok_species;

  foreach my $species (@{$local_species||[]}) {
    my $sci_name        = $hub->species_defs->get_config($species, 'SPECIES_SCIENTIFIC_NAME');
    my $assembly_param  = $hub->species_defs->get_config($species, 'THR_ASSEMBLY_PARAM')
                            || 'ASSEMBLY_ACCESSION';
    my $assembly        = $hub->species_defs->get_config($species, $assembly_param);
    my $key             = $assembly_param eq 'ASSEMBLY_ACCESSION' ? 'accession' : 'name';

    if ($thr_species->{$sci_name}) {
      ## Check that we have the right assembly, because otherwise mouse strains will all match
      my $found = 0;
      ($found, $key) = $self->_find_assembly($thr_species->{$sci_name}, $assembly_param, $key, $assembly);
      if ($found) {
        $ok_species->{$species} = {'assembly_param' => $key, 'assembly' => $assembly};
      }
    }
    else {
      ## No exact match, so try everything else
      while (my ($sp_name, $info) = each (%$thr_species)) {
        my $found = 0;
        ($found, $key) = $self->_find_assembly($info, $assembly_param, $key, $assembly);;
        if ($found) {
          $ok_species->{$species} = {'assembly_param' => $key, 'assembly' => $assembly};
          delete $thr_species->{$sp_name};
          last;
        }
      }
    }
  }  
  return $ok_species;
}

sub _find_assembly {
  my ($self, $info, $assembly_param, $key, $assembly) = @_;
  my $found = 0;

  if ($assembly_param eq 'ASSEMBLY_ACCESSION') {
    foreach (@$info) {
      if ($_->{'accession'} eq $assembly) {
        $found = 1;
        last;
      }
    }
  }
  else {
    ## Check name and synonyms
    foreach (@$info) {
      if ($_->{'name'} eq $assembly) {
        $found = 1;
      }
      else {
        foreach (@{$_->{'synonyms'}||[]}) {
          if ($_ eq $assembly) {
            $found = 1;
            $key = 'synonyms';
            last;
          }
        }
      }
      last if $found;
    }
  }
  return ($found, $key);
}

1;
