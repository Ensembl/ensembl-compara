package EnsEMBL::Web::Configuration::UserData;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration );

## Don't cache tree for user data
sub tree_cache_key {
  return undef;
}

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'ManageData';
}

sub is_configurable {
  ## Not currently used - seems to me to make sense to have links on all pages
  my $self = shift;
  ## Can we do upload/DAS on this page?
  my $flag = 0;
  my $referer = $self->object->param('_referer');
  my @path = split(/\//, $referer);
  my $type = $path[2];
  if ($type eq 'Location' || $type eq 'Gene' || $type eq 'Transcript') {
    (my $action = $path[3]) =~ s/\?.*//;
    my $vc = $self->object->session->getViewConfig( $type, $action);
    $flag = 1 if $vc && $vc->can_upload;
  }
  return $flag;
}

sub global_context { return $_[0]->_user_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return undef;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return undef;  }

sub populate_tree {
  my $self = shift;

  my $has_logins = $self->{object}->species_defs->ENSEMBL_LOGINS;
  my $is_configurable = $self->is_configurable;
  $has_logins = 0 unless $is_configurable;

  ## Upload "wizard"
  $self->create_node( 'SelectFile', "Upload Data",
    [qw(select_file EnsEMBL::Web::Component::UserData::SelectFile)], 
    { 'availability' => 1 }
  );
  $self->create_node( 'UploadFile', '',
    [], { 'availability' => 1, 'no_menu_entry' => 1,
    'command' => 'EnsEMBL::Web::Command::UserData::UploadFile'}
  );
  $self->create_node( 'MoreInput', '',
    [qw(more_input EnsEMBL::Web::Component::UserData::MoreInput)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'UploadFeedback', '',
    [qw(upload_feedback EnsEMBL::Web::Component::UserData::UploadFeedback)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );

  ## Share data "wizard"
  $self->create_node( 'SelectShare', "Share Data",
    [qw(select_share EnsEMBL::Web::Component::UserData::SelectShare)], 
    { 'availability' => 1, 'no_menu_entry' => 1, 'filters' => [qw(Shareable)] }
  );
  $self->create_node( 'CheckShare', '',
    [], { 'availability' => 1, 'no_menu_entry' => 1,
    'command' => 'EnsEMBL::Web::Command::UserData::CheckShare'}
  );
  $self->create_node( 'ShareURL', '',
    [qw(share_url EnsEMBL::Web::Component::UserData::ShareURL)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );

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

  $self->create_node( 'SelectServer', "Attach DAS",
   [qw(select_server EnsEMBL::Web::Component::UserData::SelectServer)], 
    { 'availability' => 1 }
  );
  $self->create_node( 'CheckServer', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::CheckServer',
    'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'DasSources', '',
   [qw(das_sources EnsEMBL::Web::Component::UserData::DasSources)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'ValidateDAS', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::ValidateDAS',
    'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'DasSpecies', '',
   [qw(das_species EnsEMBL::Web::Component::UserData::DasSpecies)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'DasCoords', '',
   [qw(das_coords EnsEMBL::Web::Component::UserData::DasCoords)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'AttachDAS', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::AttachDAS', 
    'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'DasFeedback', '',
   [qw(das_feedback EnsEMBL::Web::Component::UserData::DasFeedback)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );

  ## URL attachment
  $self->create_node( 'SelectURL', "Attach URL Data",
   [qw(select_url EnsEMBL::Web::Component::UserData::SelectURL)], 
    { 'availability' => 1 }
  );
  $self->create_node( 'AttachURL', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::AttachURL', 
    'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'UrlFeedback', '',
   [qw(url_feedback EnsEMBL::Web::Component::UserData::UrlFeedback)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );

  ## Saving remote data
  $self->create_node( 'ShowRemote', '',
   [qw(show_remote EnsEMBL::Web::Component::UserData::ShowRemote)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'SaveRemote', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::SaveRemote', 
    'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'RemoteFeedback', '',
   [qw(remote_feedback EnsEMBL::Web::Component::UserData::RemoteFeedback)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );

  ## Data management
  $self->create_node( 'ManageData', "Manage Data",
    [qw(manage_remote EnsEMBL::Web::Component::UserData::ManageData)
    ], { 'availability' => 1, 'concise' => 'Manage Data' }
  );
  $self->create_node( 'RenameRecord', '',
    [qw(manage_remote EnsEMBL::Web::Component::UserData::RenameRecord)
    ], { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'RenameTempData', '',
    [qw(manage_remote EnsEMBL::Web::Component::UserData::RenameTempData)
    ], { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'SaveRecord', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::SaveRecord',
     'no_menu_entry' => 1 }
  );
  $self->create_node( 'SaveTempData', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::SaveTempData',
     'no_menu_entry' => 1 }
  );
  $self->create_node( 'ShareRecord', '',
    [], { 'command' => 'EnsEMBL::Web::Command::ShareRecord',
     'no_menu_entry' => 1 }
  );
  $self->create_node( 'SaveUpload', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::SaveUpload',
     'no_menu_entry' => 1 }
  );
  $self->create_node( 'DeleteUpload', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::DeleteUpload',
     'no_menu_entry' => 1 }
  );
  $self->create_node( 'DeleteRemote', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::DeleteRemote',
     'no_menu_entry' => 1 }
  );

  $self->create_node( 'IDConversion', "Stable ID Conversion", 
     [ qw(idmapper  EnsEMBL::Web::Component::UserData::IDmapper) ],
     { 'no_menu_entry' => 1 }
  );

  ## Data conversion
  my $convert_menu = $self->create_submenu( 'Conversion', 'Data Converters' );
  my $mappings = $self->object->species_defs->get_config($self->object->species, 'ASSEMBLY_MAPPINGS');
  my $available = ref($mappings) eq 'ARRAY' ? 1 : 0;
  $convert_menu->append(
    $self->create_node( 'SelectFeatures', 'Assembly Converter', 
      [qw(select_features EnsEMBL::Web::Component::UserData::SelectFeatures)],
      {'availability' => $available},
    )
  );
  $convert_menu->append(
    $self->create_node( 'CheckConvert', '', [],
      {'command' => 'EnsEMBL::Web::Command::UserData::CheckConvert',
      'availability' => 1, 'no_menu_entry' => 1},
    )
  );
  $convert_menu->append(
    $self->create_node( 'ConvertFeatures', '', [],
      {'command' => 'EnsEMBL::Web::Command::UserData::ConvertFeatures',
      'availability' => 1, 'no_menu_entry' => 1},
    )
  );
  $convert_menu->append(
    $self->create_node( 'PreviewConvert', 'Files Converted', 
      [qw(conversion_done EnsEMBL::Web::Component::UserData::PreviewConvert)],
      {'availability' => 1, 'no_menu_entry' => 1},
    )
  );
  $convert_menu->append(
    $self->create_node( 'MapIDs', '', [],
      {'command' => 'EnsEMBL::Web::Command::UserData::MapIDs',
      'availability' => 1, 'no_menu_entry' => 1},
    )
  );

  $convert_menu->append(
     $self->create_node( 'SelectOutput', '', 
      [qw(command  EnsEMBL::Web::Component::UserData::SelectOutput)],
      {'availability' => 1, 'no_menu_entry' => 1},
    )
  );
  $convert_menu->append(
    $self->create_node( 'UploadStableIDs', 'ID History Converter', 
      [qw(upload_stable_ids EnsEMBL::Web::Component::UserData::UploadStableIDs)],
      {'availability' => 'has_id_mapping'},
    )
  );
  $convert_menu->append(
    $self->create_node( 'PreviewConvertIDs', 'Files Converted',
      [qw(conversion_done EnsEMBL::Web::Component::UserData::PreviewConvertIDs)],
      {'availability' => 1, 'no_menu_entry' => 1},
    )
  );
  ## Add "invisible" nodes used by interface but not displayed in navigation
  $self->create_node( 'Message', '',
    [qw(message EnsEMBL::Web::Component::CommandMessage
        )],
      { 'no_menu_entry' => 1 }
  );
}


1;
