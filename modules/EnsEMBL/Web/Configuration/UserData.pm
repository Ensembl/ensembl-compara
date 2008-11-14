package EnsEMBL::Web::Configuration::UserData;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub set_default_action {
  my $self = shift;
  my $vc  = $self->object->get_viewconfig;
  if ($self->is_configurable) {
    $self->{_data}{default} = 'Upload';
  }
  else {
    $self->{_data}{default} = 'ManageUpload';
  }
}

sub is_configurable {
  my $self = shift;
  ## Can we do upload/DAS on this page?
  my $flag = 0;
  my $referer = $self->object->param('_referer');
  my @path = split(/\//, $referer);
  my $type = $path[2];
  if ($type eq 'Location' || $type eq 'Gene' || $type eq 'Transcript') {
    (my $action = $path[3]) =~ s/\?(.)+//;
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

  ## N.B. Most of these will be empty, as content is created using 
  ## wizard methods (below) and Wizard::Node::UserData
  my $has_logins = $self->{object}->species_defs->ENSEMBL_LOGINS;
  my $is_configurable = $self->is_configurable;
  $has_logins = 0 unless $is_configurable;

  my $uploaded_menu = $self->create_submenu( 'Uploaded', 'Uploaded data' );
  $uploaded_menu->append($self->create_node( 'Upload', "Upload Data",
   [], { 'availability' => $is_configurable }
  ));
  $uploaded_menu->append($self->create_node( 'ShareUpload', "Share Data",
    [], { 'availability' => 1 }
  ));
  $uploaded_menu->append($self->create_node( 'ManageUpload', "Manage Uploads",
    [qw(manage_upload   EnsEMBL::Web::Component::UserData::ManageUpload)
    ], { 'availability' => 1, 'concise' => 'Manage Uploads' }
  ));

  my $attached_menu = $self->create_submenu( 'Attached', 'Remote data' );
  $attached_menu->append($self->create_node( 'AttachDAS', "Attach DAS",
   [], { 'availability' => $is_configurable }
  ));
  $attached_menu->append($self->create_node( 'AttachURL', "Attach URL Data",
   [], { 'availability' => $is_configurable }
  ));
  $attached_menu->append($self->create_node( 'ManageRemote', "Manage Data",
    [qw(manage_remote EnsEMBL::Web::Component::UserData::ManageRemote)
    ], { 'availability' => 1, 'concise' => 'Manage Data' }
  ));

  ## Add "invisible" nodes used by interface but not displayed in navigation
  $self->create_node( 'Message', '',
    [qw(message EnsEMBL::Web::Component::CommandMessage
        )],
      { 'no_menu_entry' => 1 }
  );
  $self->create_node( 'SaveUpload', '',
    [qw(save_upload EnsEMBL::Web::Component::UserData::SaveUpload
        )],
      { 'no_menu_entry' => 1 }
  );
  $self->create_node( 'SaveRemote', '',
    [qw(save_remote EnsEMBL::Web::Component::UserData::SaveRemote
        )],
      { 'no_menu_entry' => 1 }
  );
}


#####################################################################################

## Wizards have to be done the 'old-fashioned' way, instead of using Magic

sub upload {
  my $self   = shift;
  my $object = $self->{'object'};

  my $wizard = $self->wizard;

  ## CREATE NODES
  my $node  = 'EnsEMBL::Web::Wizard::Node::UploadData';
#  my $session  = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'check_session');
#  my $warning  = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'overwrite_warning' );
#  my $save     = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'overwrite_save' );
  my $select   = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'select_file' );
  my $upload   = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'upload');
  my $more     = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'more_input');
  my $feedback = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'upload_feedback');

  ## SET UP CONNECTION BUTTONS
#  $wizard->add_connection( from => $warning,  to => $save);
  $wizard->add_connection( from => $select,   to => $upload);
  $wizard->add_connection( from => $upload,   to => $more);
  $wizard->add_connection( from => $more,     to => $feedback);
}

sub share_upload {
  my $self   = shift;
  my $object = $self->{'object'};

  my $wizard = $self->wizard;

  ## CREATE NODES
  my $node  = 'EnsEMBL::Web::Wizard::Node::UploadData';
  my $shareable = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'check_shareable', backtrack => 1);
  my $warning   = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'no_shareable' );
  my $select    = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'select_upload' );
  my $check     = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'check_save' );
  my $share     = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'show_shareable' );

  ## SET UP CONNECTION BUTTONS
  $wizard->add_connection( from => $select, to => $check);
}

sub attach_das {
  my $self   = shift;
  my $object = $self->{'object'};

  my $wizard = $self->wizard;
  
  # Page:     select_server
  #               |
  #               V
  # Page:    select_das                
  #               |                        
  #               V                        
  # Logic:  validate_das-------+           
  #           |    ^           |           
  #           |    |           V           
  # Page:     |    |   select_das_species  
  #           |    |           |           
  #           |    |           V           
  # Page:     |    +-->select_das_coords   
  #           V                            
  # Logic:  attach_das
  #           |
  #           V
  # Page:   das_feedback                

  ## CREATE NODES
  my $node  = 'EnsEMBL::Web::Wizard::Node::RemoteData';
  my $server        = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'select_server' );
  my $source        = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'select_das', backtrack => 1 );
  my $validate_das  = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'validate_das');
  my $species       = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'select_das_species', 'backtrack' => 1);
  my $coords        = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'select_das_coords', 'backtrack' => 1);
  my $attach_das    = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'attach_das');
  
  # END POINTS:
  my $feedback    = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'das_feedback');

  ## LINK PAGE NODES TOGETHER
  $wizard->add_connection( from => $server,  to => $source);
  $wizard->add_connection( from => $source,  to => $validate_das);
  $wizard->add_connection( from => $species, to => $coords);
  $wizard->add_connection( from => $coords,  to => $validate_das);
}

sub save_remote {
  my $self   = shift;
  my $object = $self->{'object'};

  my $wizard = $self->wizard;
  my $node  = 'EnsEMBL::Web::Wizard::Node::RemoteData';
  
  ## CREATE NODES
  my $start = $wizard->create_node( object => $object, module => $node, type => 'page', name => 'show_tempdas');
  my $save  = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'save_tempdas');
  my $end   = $wizard->create_node( object => $object, module => $node, type => 'page', name => 'ok_tempdas');

  ## SET UP CONNECTION BUTTONS
  $wizard->add_connection( from => $start, to => $save);
  $wizard->add_connection( from => $save, to => $end);
}

sub attach_url {
  my $self   = shift;
  my $object = $self->{'object'};

  my $wizard = $self->wizard;
  my $node  = 'EnsEMBL::Web::Wizard::Node::RemoteData';
  
  my $select    = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'select_url');
  my $attach    = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'attach_url');
  my $feedback  = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'url_feedback');

  ## SET UP CONNECTION BUTTONS
  $wizard->add_connection( from => $select,   to => $attach);
}

1;
