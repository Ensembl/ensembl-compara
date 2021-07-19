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

package EnsEMBL::Web::Document::Element::ModalButtons;

# Generates the tools buttons below the control panel left menu - add track, reset configuration, save configuration

use strict;

use base qw(EnsEMBL::Web::Document::Element::ToolButtons);

sub label_classes {
  return {
    'Save configuration as...' => 'save',
    'Load configuration'       => 'config-load',
    'Reset configuration'      => 'config-reset',
    'Reset track order'        => 'order-reset',
    'Custom tracks'            => 'data',
  };
}

sub init {
  my $self       = shift;  
  my $controller = shift;
  my $hub        = $controller->hub;
  
  if ($hub->script eq 'Config') {
    my $action       = $hub->action;
    my $image_config = $hub->get_viewconfig($action)->image_config_type;
       $image_config = $hub->get_imageconfig($image_config) if $image_config;
    my $rel          = "modal_config_$action";
       $rel         .= '_' . lc $hub->species if $image_config && $image_config->get_parameter('multi_species') && $hub->referer->{'ENSEMBL_SPECIES'} ne $hub->species;

    if ($image_config) {
      $self->add_entry({
        caption => 'Search for track hubs',
        class   => 'modal_link search',
        url     => $hub->url({
          type    => 'UserData',
          action  => 'TrackHubSearch',
          __clear => 1
        })
      });
      
      $self->add_entry({
        caption => 'Custom tracks',
        class   => 'modal_link data',
        url     => $hub->url({
          type    => 'UserData',
          action  => 'ManageData',
          __clear => 1
        })
      });
    }

    $self->add_entry({
      caption => 'Manage configurations',
      class   => 'modal_link config-manage',
      rel     => 'modal_user_data',
      url     => $hub->url({
        type    => 'UserData',
        action  => 'ManageConfigs',
        __clear => 1 
      })
    });

    $self->add_entry({
      caption => 'Reset configuration',
      class   => 'modal_link config-reset',
      rel     => $rel,
      url     => $hub->url('Config', {
        reset => 1
      })
    });
    
    if ($image_config) {
      if ($image_config->get_parameter('sortable_tracks')) {
        $self->add_entry({
          caption => 'Reset track order',
          class   => 'modal_link order-reset',
          rel     => $rel,
          url     => $hub->url('Config', {
            reset   => 'track_order',
            __clear => 1 
          })
        });
      }
    }
  }
}

1;
