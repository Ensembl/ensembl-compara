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
  my $tools_menu  = $self->create_submenu('Conversion',     'Online Tools');

  ## Upload "wizard"
  $data_menu->append($self->create_node('SelectFile',     'Add your data', [qw(select_file  EnsEMBL::Web::Component::UserData::SelectFile)]));
  $data_menu->append($self->create_node('MoreInput',      '',              [qw(more_input   EnsEMBL::Web::Component::UserData::MoreInput)]));
  $data_menu->append($self->create_node('UploadFeedback', '',              [qw(feedback     EnsEMBL::Web::Component::UserData::UploadFeedback   parsed EnsEMBL::Web::Component::UserData::UploadParsed)]));
  $data_menu->append($self->create_node('RemoteFeedback', '',              [qw(feedback     EnsEMBL::Web::Component::UserData::RemoteFeedback   parsed EnsEMBL::Web::Component::UserData::UploadParsed)]));
  $data_menu->append($self->create_node('SelectShare',    '',              [qw(select_share EnsEMBL::Web::Component::UserData::SelectShare)], { filters => [ 'Shareable' ] }));
  $data_menu->append($self->create_node('ShareURL',       '',              [qw(share_url    EnsEMBL::Web::Component::UserData::ShareURL)]));
  
  $data_menu->append($self->create_node('UploadFile',   '', [], { command => 'EnsEMBL::Web::Command::UserData::UploadFile'   }));
  $data_menu->append($self->create_node('AttachRemote', '', [], { command => 'EnsEMBL::Web::Command::UserData::AttachRemote' }));
  $data_menu->append($self->create_node('CheckShare',   '', [], { command => 'EnsEMBL::Web::Command::UserData::CheckShare'   }));

  ## Trackhub registry
  $data_menu->append($self->create_node('SelectHub',     'Track Hubs', [qw(track_hubs  EnsEMBL::Web::Component::UserData::SelectHub)]));
  
  ## Attach DAS "wizard"
  # Component:     SelectServer
  #                    |
  #                    V
  # Command:        CheckServer
  #                    |
  #                    V
  # Component:     DasSources                
  #                   |                        
  #                   V                        
  # Command:  ValidateDAS---------+           
  #               |   ^  \        |           
  #               |   |   \       V           
  # Component:    |   |    \   DasSpecies  
  #               |   |     \     |           
  #               |   |      V    V           
  # Component:    |   +------DasCoords   
  #               V                            
  # Command:  AttachDAS
  #               |
  #               V
  # Component:  DasFeedback                

  $data_menu->append($self->create_node('SelectServer', 'Attach DAS', [qw(select_server EnsEMBL::Web::Component::UserData::SelectServer)]));
  $data_menu->append($self->create_node('DasSources',   '',           [qw(das_sources   EnsEMBL::Web::Component::UserData::DasSources)]));
  $data_menu->append($self->create_node('DasSpecies',   '',           [qw(das_species   EnsEMBL::Web::Component::UserData::DasSpecies)]));
  $data_menu->append($self->create_node('DasCoords',    '',           [qw(das_coords    EnsEMBL::Web::Component::UserData::DasCoords)]));
  $data_menu->append($self->create_node('DasFeedback',  '',           [qw(das_feedback  EnsEMBL::Web::Component::UserData::DasFeedback)]));
  
  $data_menu->append($self->create_node('CheckServer', '', [], { command => 'EnsEMBL::Web::Command::UserData::CheckServer' }));
  $data_menu->append($self->create_node('ValidateDAS', '', [], { command => 'EnsEMBL::Web::Command::UserData::ValidateDAS' }));
  $data_menu->append($self->create_node('AttachDAS',   '', [], { command => 'EnsEMBL::Web::Command::UserData::AttachDAS'   }));
  
  ## Saving remote data
  $data_menu->append($self->create_node('ShowRemote',      '', [qw(show_remote     EnsEMBL::Web::Component::UserData::ShowRemote)]));
  $data_menu->append($self->create_node('ConfigureBigWig', '', [qw(remote_feedback EnsEMBL::Web::Component::UserData::ConfigureBigWig)]));
  
  $data_menu->append($self->create_node('SaveExtraConfig', '', [], { command => 'EnsEMBL::Web::Command::UserData::SaveExtraConfig' }));

  ## Data management
  $data_menu->append($self->create_node('ManageData',            'Manage Data', [qw(manage_remote EnsEMBL::Web::Component::UserData::ManageData)]));
  $data_menu->append($self->create_node('IDConversion',          '',            [qw(idmapper      EnsEMBL::Web::Component::UserData::IDmapper)]));
  $data_menu->append($self->create_node('ConsequenceCalculator', '',            [qw(consequence   EnsEMBL::Web::Component::UserData::ConsequenceTool)])); 
  
  $data_menu->append($self->create_node('ModifyData',  '', [], { command => 'EnsEMBL::Web::Command::UserData::ModifyData' }));
  $data_menu->append($self->create_node('ShareRecord', '', [], { command => 'EnsEMBL::Web::Command::ShareRecord'          }));
  $data_menu->append($self->create_node('Unshare',     '', [], { command => 'EnsEMBL::Web::Command::UnshareRecord'        }));
  
  ## FeatureView 
  $data_menu->append($self->create_node('FeatureView', 'Features on Karyotype', [qw(featureview EnsEMBL::Web::Component::UserData::FeatureView)], { availability => @{$sd->ENSEMBL_CHROMOSOMES} }));
  
  $data_menu->append($self->create_node('FviewRedirect', '', [], { command => 'EnsEMBL::Web::Command::UserData::FviewRedirect'})); 
  
  ## Configuration management
  $config_menu->append($self->create_node('ManageConfigs',           'Configurations for this page', [qw(manage_config EnsEMBL::Web::Component::UserData::ManageConfigs)]));
  $config_menu->append($self->create_node('ManageConfigs/All',       'All configurations',           [qw(manage_config EnsEMBL::Web::Component::UserData::ManageConfigs/all)]));
  $config_menu->append($self->create_node('ManageConfigs/Update',    '',                             [qw(manage_config EnsEMBL::Web::Component::UserData::ManageConfigs/update)]));
  $config_menu->append($self->create_node('ManageConfigSets',        'Configuration sets',           [qw(manage_sets   EnsEMBL::Web::Component::UserData::ManageConfigSets)]));
  $config_menu->append($self->create_node('ManageConfigSets/Update', '',                             [qw(manage_sets   EnsEMBL::Web::Component::UserData::ManageConfigSets/update)]));
  
  $config_menu->append($self->create_node('ModifyConfig', '', [], { command => 'EnsEMBL::Web::Command::UserData::ModifyConfig' }));
  
  ## Data conversion
  $tools_menu->append($self->create_node('UploadVariations',  'Variant Effect Predictor', [qw(upload_snps       EnsEMBL::Web::Component::UserData::UploadVariations)])) unless $sd->ENSEMBL_VEP_ENABLED; # only if new VEP is not enabled
  unless ($sd->ENSEMBL_AC_ENABLED) {
    $tools_menu->append($self->create_node('SelectFeatures',    'Assembly Converter',       [qw(select_features   EnsEMBL::Web::Component::UserData::SelectFeatures)]));
    $tools_menu->append($self->create_node('PreviewConvert',    '',                         [qw(conversion_done   EnsEMBL::Web::Component::UserData::PreviewConvert)]));
  }

  $tools_menu->append($self->create_node('UploadStableIDs',   'ID History Converter',     [qw(upload_stable_ids EnsEMBL::Web::Component::UserData::UploadStableIDs)]));
  $tools_menu->append($self->create_node('PreviewConvertIDs', '',                         [qw(conversion_done   EnsEMBL::Web::Component::UserData::PreviewConvertIDs)]));
  $tools_menu->append($self->create_node('SelectOutput',      '',                         [qw(select_output     EnsEMBL::Web::Component::UserData::SelectOutput)]));
  
  $tools_menu->append($self->create_node('SNPConsequence',  '', [], { command => 'EnsEMBL::Web::Command::UserData::SNPConsequence'  }));
  $tools_menu->append($self->create_node('CheckConvert',    '', [], { command => 'EnsEMBL::Web::Command::UserData::CheckConvert'    }));
  $tools_menu->append($self->create_node('ConvertFeatures', '', [], { command => 'EnsEMBL::Web::Command::UserData::ConvertFeatures' }));
  $tools_menu->append($self->create_node('MapIDs',          '', [], { command => 'EnsEMBL::Web::Command::UserData::MapIDs'          }));
  $tools_menu->append($self->create_node('DropUpload',      '', [], { command => 'EnsEMBL::Web::Command::UserData::DropUpload'      }));
  
}

1;
