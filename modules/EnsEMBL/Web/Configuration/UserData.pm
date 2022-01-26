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

  ####### USERDATA NODES #########
  ## Visible nodes - no top-level menu any more 
  $self->create_node('ManageData',            'Custom tracks', [qw(
                    manage_remote EnsEMBL::Web::Component::UserData::ManageData
    )]);
  my $not_protein = $self->hub->referer->{'ENSEMBL_ACTION'} eq 'ProteinSummary' ? 0 : 1;
  $self->create_node('TrackHubSearch',     'Track Hub Registry Search', 
    [qw(track_hubs  EnsEMBL::Web::Component::UserData::TrackHubSearch)],
    { 'availability' => $not_protein }
    );

  ## Non-visible nodes for various interfaces

  ## Upload "wizard"
  $self->create_node('AddFile',   '', [], { command => 'EnsEMBL::Web::Command::UserData::AddFile'   });
  $self->create_node('SelectFile',     'Add your data', [qw(select_file  EnsEMBL::Web::Component::UserData::SelectFile)], {'no_menu_entry' => 1});
  $self->create_node('UploadFeedback', '',              [qw(feedback     EnsEMBL::Web::Component::UserData::UploadFeedback   parsed EnsEMBL::Web::Component::UserData::UploadParsed)]);
  $self->create_node('RemoteFeedback', '',              [qw(feedback     EnsEMBL::Web::Component::UserData::RemoteFeedback   parsed EnsEMBL::Web::Component::UserData::UploadParsed)]);
  $self->create_node('SelectShare',    '',              [qw(select_share EnsEMBL::Web::Component::UserData::SelectShare)], { filters => [ 'Shareable' ] });
  $self->create_node('ShareURL',       '',              [qw(share_url    EnsEMBL::Web::Component::UserData::ShareURL)]);
  
  $self->create_node('RefreshUpload',   '', [], { command => 'EnsEMBL::Web::Command::UserData::RefreshUpload'   });
  $self->create_node('FlipTrack',       '', [], { command => 'EnsEMBL::Web::Command::UserData::FlipTrack' });
  $self->create_node('CheckShare',   '', [], { command => 'EnsEMBL::Web::Command::UserData::CheckShare'   });
  ## Data management

  ## Trackhub attachment
  $self->create_node('TrackHubRedirect',   '', [], { command => 'EnsEMBL::Web::Command::UserData::TrackHubRedirect'   });
  $self->create_node('RefreshTrackHub',   '', [], { command => 'EnsEMBL::Web::Command::UserData::RefreshTrackHub'   });

  ## Trackhub registry
  $self->create_node('TrackHubResults',     'Track Hub Registry Search', [qw(track_hubs  EnsEMBL::Web::Component::UserData::TrackHubResults)], {'no_menu_entry' => 1});
  
  ## Saving remote data
  $self->create_node('ConfigureGraph',  '', [qw(remote_feedback EnsEMBL::Web::Component::UserData::ConfigureGraph)]);
  
  $self->create_node('SaveExtraConfig', '', [], { command => 'EnsEMBL::Web::Command::UserData::SaveExtraConfig' });
  
  $self->create_node('ModifyData',  '', [], { command => 'EnsEMBL::Web::Command::UserData::ModifyData' });
  $self->create_node('ShareRecord', '', [], { command => 'EnsEMBL::Web::Command::ShareRecord'          });
  $self->create_node('Unshare',     '', [], { command => 'EnsEMBL::Web::Command::UnshareRecord'        });
  
  ## FeatureView 
  if ($self->hub->action eq 'FeatureView') {
    $self->create_node('FeatureView', 'Features on Karyotype', [qw(featureview EnsEMBL::Web::Component::UserData::FeatureView)], { availability => scalar @{$sd->ENSEMBL_CHROMOSOMES}});
  }

  $self->create_node('FviewRedirect', '', [], { command => 'EnsEMBL::Web::Command::UserData::FviewRedirect'}); 
  
  ## Configuration management
  my $config_menu = $self->create_node('ManageConfigs', 'Manage Configurations', [qw(manage_config EnsEMBL::Web::Component::UserData::ManageConfigs)]);
}

1;
