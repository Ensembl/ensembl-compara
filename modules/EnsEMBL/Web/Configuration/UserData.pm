# $Id$

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
  my $self = shift;

  my $data_menu = $self->create_submenu('CustomData', 'Custom Data');

  ## Upload "wizard"
  $data_menu->append($self->create_node( 'SelectFile', 'Add your data',
    [qw(select_file EnsEMBL::Web::Component::UserData::SelectFile)], 
    { 'availability' => 1 }
  ));
  $self->create_node( 'UploadFile', '',
    [], { 'availability' => 1, 'no_menu_entry' => 1,
    'command' => 'EnsEMBL::Web::Command::UserData::UploadFile'}
  );
  $self->create_node( 'MoreInput', '',
    [qw(more_input EnsEMBL::Web::Component::UserData::MoreInput)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'UploadFeedback', '',
    [qw(
      upload_feedback EnsEMBL::Web::Component::UserData::UploadFeedback
      upload_parsed   EnsEMBL::Web::Component::UserData::UploadParsed
    )], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  ## URL attachment
  $self->create_node( 'AttachRemote', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::AttachRemote', 
    'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'RemoteFeedback', '',
   [qw(
      remote_feedback  EnsEMBL::Web::Component::UserData::RemoteFeedback
      remote_parsed    EnsEMBL::Web::Component::UserData::UploadParsed
    )],
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

  $data_menu->append($self->create_node( 'SelectServer', "Attach DAS",
   [qw(select_server EnsEMBL::Web::Component::UserData::SelectServer)], 
    { 'availability' => 1 }
  ));
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


  ## Saving remote data
  $self->create_node( 'ShowRemote', '',
   [qw(show_remote EnsEMBL::Web::Component::UserData::ShowRemote)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'ConfigureBigWig', '',
   [qw(remote_feedback EnsEMBL::Web::Component::UserData::ConfigureBigWig)], 
    { 'availability' => 1, 'no_menu_entry' => 1 }
  );
  $self->create_node( 'SaveExtraConfig', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::SaveExtraConfig', 
    'availability' => 1, 'no_menu_entry' => 1 }
  );

  ## Data management
  $data_menu->append($self->create_node( 'ManageData', "Manage Data",
    [qw(manage_remote EnsEMBL::Web::Component::UserData::ManageData)
    ], { 'availability' => 1, 'concise' => 'Manage Data' }
  ));
  
  $self->create_node( 'ModifyData', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UserData::ModifyData',
     'no_menu_entry' => 1 }
  );
  
  $self->create_node( 'ShareRecord', '',
    [], { 'command' => 'EnsEMBL::Web::Command::ShareRecord',
     'no_menu_entry' => 1 }
  );

  $self->create_node( 'Unshare', '',
    [], { 'command' => 'EnsEMBL::Web::Command::UnshareRecord',
     'no_menu_entry' => 1 }
  );

  $self->create_node( 'IDConversion', "Stable ID Conversion", 
    [ qw(idmapper  EnsEMBL::Web::Component::UserData::IDmapper) ],
    { 'no_menu_entry' => 1 }
  );
  $self->create_node ('ConsequenceCalculator', '',
    [ qw(consequence EnsEMBL::Web::Component::UserData::ConsequenceTool)],
    {'no_menu_entry' => 1}
  ); 
 
  ## FeatureView 
  $data_menu->append($self->create_node('FeatureView', 'Features on Karyotype',
    [qw(featureview   EnsEMBL::Web::Component::UserData::FeatureView)],
    {'availability' => @{$self->hub->species_defs->ENSEMBL_CHROMOSOMES}},
  ));
  $self->create_node ('FviewRedirect', '',
    [], {'command' => 'EnsEMBL::Web::Command::UserData::FviewRedirect', 
      'no_menu_entry' => 1}
  ); 


  ## Data conversion
  my $tools_menu = $self->create_submenu( 'Conversion', 'Online Tools' );
  $tools_menu->append(
    $self->create_node( 'UploadVariations', 'Variant Effect Predictor',
      [qw(upload_snps EnsEMBL::Web::Component::UserData::UploadVariations)],
      {'availability' => 1,},
    )
  );
  $tools_menu->append(
    $self->create_node( 'SNPConsequence', '', [],
      {'command' => 'EnsEMBL::Web::Command::UserData::SNPConsequence',
      'availability' => 1, 'no_menu_entry' => 1},
    )
  );

  $tools_menu->append(
    $self->create_node( 'SelectFeatures', 'Assembly Converter', 
      [qw(select_features EnsEMBL::Web::Component::UserData::SelectFeatures)],
      {'availability' => 1},
    )
  );
  $tools_menu->append(
    $self->create_node( 'CheckConvert', '', [],
      {'command' => 'EnsEMBL::Web::Command::UserData::CheckConvert',
      'availability' => 1, 'no_menu_entry' => 1},
    )
  );
  $tools_menu->append(
    $self->create_node( 'ConvertFeatures', '', [],
      {'command' => 'EnsEMBL::Web::Command::UserData::ConvertFeatures',
      'availability' => 1, 'no_menu_entry' => 1},
    )
  );
  $tools_menu->append(
    $self->create_node( 'PreviewConvert', 'Files Converted', 
      [qw(conversion_done EnsEMBL::Web::Component::UserData::PreviewConvert)],
      {'availability' => 1, 'no_menu_entry' => 1},
    )
  );
  $tools_menu->append(
    $self->create_node( 'MapIDs', '', [],
      {'command' => 'EnsEMBL::Web::Command::UserData::MapIDs',
      'availability' => 1, 'no_menu_entry' => 1},
    )
  );

  $tools_menu->append(
     $self->create_node( 'SelectOutput', '', 
      [qw(command  EnsEMBL::Web::Component::UserData::SelectOutput)],
      {'availability' => 1, 'no_menu_entry' => 1},
    )
  );
  $tools_menu->append(
    $self->create_node( 'UploadStableIDs', 'ID History Converter', 
      [qw(upload_stable_ids EnsEMBL::Web::Component::UserData::UploadStableIDs)],
      {'availability' => 1},
    )
  );
  $tools_menu->append(
    $self->create_node( 'PreviewConvertIDs', 'Files Converted',
      [qw(conversion_done EnsEMBL::Web::Component::UserData::PreviewConvertIDs)],
      {'availability' => 1, 'no_menu_entry' => 1},
    )
  );

    $self->create_node( 'DropUpload', '',
    [], { 'availability' => 1, 'no_menu_entry' => 1,
    'command' => 'EnsEMBL::Web::Command::UserData::DropUpload'}
  );
 
  ## REGION REPORT
  $tools_menu->append(
    $self->create_node( 'SelectReportOptions', 'Region Report',
      [qw(report_options EnsEMBL::Web::Component::UserData::SelectReportOptions)],
      {'availability' => 1},
    )
  );
  $tools_menu->append(
    $self->create_node( 'CheckRegions', '', [],
      {'command' => 'EnsEMBL::Web::Command::UserData::CheckRegions',
      'availability' => 1, 'no_menu_entry' => 1},
    )
  );

  $tools_menu->append(
    $self->create_node( 'RunRegionTool', '', [],
      {'command' => 'EnsEMBL::Web::Command::UserData::RunRegionTool',
      'availability' => 1, 'no_menu_entry' => 1},
    )
  );
  $tools_menu->append(
    $self->create_node( 'RegionReportOutput', 'Region Report',
      [qw(region_report EnsEMBL::Web::Component::UserData::RegionReportOutput)],
      {'availability' => 1, 'no_menu_entry' => 1},
    )
  );
 
}

1;
