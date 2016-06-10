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

package EnsEMBL::Web::Configuration::UserData;

use strict;

use base qw(EnsEMBL::Web::Configuration);

## Don't cache tree for user data
sub tree_cache_key { return undef; }

sub set_default_action {
  my $self = shift;
  $self->{'_data'}{'default'} = 'ManageData';
}

sub populate_tree {
  my $self        = shift;
  my $sd          = $self->hub->species_defs;
  my $data_menu   = $self->create_submenu('CustomData',     'Custom Data');
  my $config_menu = $self->create_submenu('Configurations', 'Manage Configurations');

  ## Upload "wizard"
  $data_menu->append($self->create_node('SelectFile',     'Add your data', [qw(select_file  EnsEMBL::Web::Component::UserData::SelectFile)], {'no_menu_entry' => 1}));
  $data_menu->append($self->create_node('MoreInput',      '',              [qw(more_input   EnsEMBL::Web::Component::UserData::MoreInput)]));
  $data_menu->append($self->create_node('UploadFeedback', '',              [qw(feedback     EnsEMBL::Web::Component::UserData::UploadFeedback   parsed EnsEMBL::Web::Component::UserData::UploadParsed)]));
  $data_menu->append($self->create_node('RemoteFeedback', '',              [qw(feedback     EnsEMBL::Web::Component::UserData::RemoteFeedback   parsed EnsEMBL::Web::Component::UserData::UploadParsed)]));
  $data_menu->append($self->create_node('SelectShare',    '',              [qw(select_share EnsEMBL::Web::Component::UserData::SelectShare)], { filters => [ 'Shareable' ] }));
  $data_menu->append($self->create_node('ShareURL',       '',              [qw(share_url    EnsEMBL::Web::Component::UserData::ShareURL)]));
  
  $data_menu->append($self->create_node('AddFile',   '', [], { command => 'EnsEMBL::Web::Command::UserData::AddFile'   }));
  $data_menu->append($self->create_node('RefreshUpload',   '', [], { command => 'EnsEMBL::Web::Command::UserData::RefreshUpload'   }));
  $data_menu->append($self->create_node('CheckShare',   '', [], { command => 'EnsEMBL::Web::Command::UserData::CheckShare'   }));
  ## Data management
  $data_menu->append($self->create_node('ManageData',            'Custom tracks', [qw(
                    manage_remote EnsEMBL::Web::Component::UserData::ManageData
                    select_file   EnsEMBL::Web::Component::UserData::SelectFile
    )]));

  ## Trackhub attachment
  $data_menu->append($self->create_node('TrackHubRedirect',   '', [], { command => 'EnsEMBL::Web::Command::UserData::TrackHubRedirect'   }));
  $data_menu->append($self->create_node('RefreshTrackHub',   '', [], { command => 'EnsEMBL::Web::Command::UserData::RefreshTrackHub'   }));

  ## Trackhub registry
  $data_menu->append($self->create_node('TrackHubSearch',     'Track Hub Registry Search', [qw(track_hubs  EnsEMBL::Web::Component::UserData::TrackHubSearch)]));
  $data_menu->append($self->create_node('TrackHubResults',     'Track Hub Registry Search', [qw(track_hubs  EnsEMBL::Web::Component::UserData::TrackHubResults)], {'no_menu_entry' => 1}));
  
  ## Saving remote data
  $data_menu->append($self->create_node('ShowRemote',      '', [qw(show_remote     EnsEMBL::Web::Component::UserData::ShowRemote)]));
  $data_menu->append($self->create_node('ConfigureBigWig', '', [qw(remote_feedback EnsEMBL::Web::Component::UserData::ConfigureBigWig)]));
  
  $data_menu->append($self->create_node('SaveExtraConfig', '', [], { command => 'EnsEMBL::Web::Command::UserData::SaveExtraConfig' }));
  
  $data_menu->append($self->create_node('ModifyData',  '', [], { command => 'EnsEMBL::Web::Command::UserData::ModifyData' }));
  $data_menu->append($self->create_node('ShareRecord', '', [], { command => 'EnsEMBL::Web::Command::ShareRecord'          }));
  $data_menu->append($self->create_node('Unshare',     '', [], { command => 'EnsEMBL::Web::Command::UnshareRecord'        }));
  
  ## FeatureView 
  if ($self->hub->action eq 'FeatureView') {
    $data_menu->append($self->create_node('FeatureView', 'Features on Karyotype', [qw(featureview EnsEMBL::Web::Component::UserData::FeatureView)], { availability => @{$sd->ENSEMBL_CHROMOSOMES}}));
  }

  $data_menu->append($self->create_node('FviewRedirect', '', [], { command => 'EnsEMBL::Web::Command::UserData::FviewRedirect'})); 
  
  ## Configuration management
  $config_menu->append($self->create_node('ManageConfigs',           'Configurations for this page', [qw(manage_config EnsEMBL::Web::Component::UserData::ManageConfigs)]));
  $config_menu->append($self->create_node('ManageConfigs/All',       'All configurations',           [qw(manage_config EnsEMBL::Web::Component::UserData::ManageConfigs/all)]));
  $config_menu->append($self->create_node('ManageConfigs/Update',    '',                             [qw(manage_config EnsEMBL::Web::Component::UserData::ManageConfigs/update)]));
  $config_menu->append($self->create_node('ManageConfigSets',        'Configuration sets',           [qw(manage_sets   EnsEMBL::Web::Component::UserData::ManageConfigSets)]));
  $config_menu->append($self->create_node('ManageConfigSets/Update', '',                             [qw(manage_sets   EnsEMBL::Web::Component::UserData::ManageConfigSets/update)]));
  
  $config_menu->append($self->create_node('ModifyConfig', '', [], { command => 'EnsEMBL::Web::Command::UserData::ModifyConfig' }));
 
}

1;
