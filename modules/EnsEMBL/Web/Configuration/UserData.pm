package EnsEMBL::Web::Configuration::UserData;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Upload';
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

  my $uploaded_menu = $self->create_submenu( 'Uploaded', 'Uploaded data' );
  $uploaded_menu->append($self->create_node( 'Upload', "Upload Data",
   [], { 'availability' => 1 }
  ));
  $uploaded_menu->append($self->create_node( 'ShareUpload', "Share Data",
    [], { 'availability' => 1 }
  ));
  $uploaded_menu->append($self->create_node( 'SaveUpload', "Save to Account",
    [], { 'availability' => $has_logins, 'concise' => 'Save Data' }
  ));
  $uploaded_menu->append($self->create_node( 'ManageUpload', "Manage Saved Data",
    [qw(manage_upload   EnsEMBL::Web::Component::UserData::ManageUpload)
    ], { 'availability' => $has_logins, 'concise' => 'Manage Data' }
  ));

  my $attached_menu = $self->create_submenu( 'Attached', 'Remote data' );
  $attached_menu->append($self->create_node( 'AttachDAS', "Attach DAS",
   [], { 'availability' => 1 }
  ));
  $attached_menu->append($self->create_node( 'AttachURL', "Attach URL Data",
   [], { 'availability' => 1 }
  ));
  $attached_menu->append($self->create_node( 'SaveRemote', "Save to Account",
    [], { 'availability' => $has_logins, 'concise' => 'Save Data' }
  ));
  $attached_menu->append($self->create_node( 'ManageRemote', "Manage Data",
    [qw(manage_remote EnsEMBL::Web::Component::UserData::ManageRemote)
    ], { 'availability' => $has_logins, 'concise' => 'Manage Data' }
  ));

  ## Add "invisible" nodes used by interface but not displayed in navigation
  $self->create_node( 'Message', '',
    [qw(message EnsEMBL::Web::Component::CommandMessage
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
  my $session  = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'check_session');
  my $warning  = $wizard->create_node( object => $object, module => $node, type => 'page', name => 'overwrite_warning' );
  my $select  = $wizard->create_node( object => $object, module => $node, type => 'page', name => 'select_file' );
  my $upload  = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'upload');
  my $more    = $wizard->create_node( object => $object, module => $node, type => 'page', name => 'more_input');
  my $feedback = $wizard->create_node( object => $object, module => $node, type => 'page', name => 'upload_feedback');

  ## SET UP CONNECTION BUTTONS
  $wizard->add_connection( from => $warning,  to => $select);
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
  my $shareable = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'check_shareable', backtrack => 0);
  my $warning   = $wizard->create_node( object => $object, module => $node, type => 'page', name => 'no_shareable' );
  my $select    = $wizard->create_node( object => $object, module => $node, type => 'page', name => 'select_upload' );
  my $check     = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'check_save');
  my $save      = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'save_upload');
  my $share  = $wizard->create_node( object => $object, module => $node, type => 'page', name => 'share_url' );

  ## SET UP CONNECTION BUTTONS
  $wizard->add_connection( from => $select, to => $check);
  $wizard->add_connection( from => $save,   to => $share);
}

sub save_upload {
  my $self   = shift;
  my $object = $self->{'object'};

  my $wizard = $self->wizard;

  ## CREATE NODES
  my $node  = 'EnsEMBL::Web::Wizard::Node::UploadData';
  my $start = $wizard->create_node( object => $object, module => $node, type => 'page', name => 'show_tempdata');
  my $save  = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'save_tempdata');
  my $end   = $wizard->create_node( object => $object, module => $node, type => 'page', name => 'ok_tempdata');

  ## SET UP CONNECTION BUTTONS
  $wizard->add_connection( from => $start, to => $save);
  $wizard->add_connection( from => $save, to => $end);
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
  # Page:    attach_das                

  ## CREATE NODES
  my $node  = 'EnsEMBL::Web::Wizard::Node::RemoteData';
  my $server        = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'select_server' );
  my $source        = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'select_das' );
  my $validate_das  = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'validate_das');
  my $species       = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'select_das_species');
  my $coords        = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'select_das_coords');
  
  # END POINTS:
  my $attach_das    = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'attach_das');

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
  
  my $session   = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'check_session');
  my $warning   = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'overwrite_warning' );
  my $select    = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'select_url');
  my $attach    = $wizard->create_node( object => $object, module => $node, type => 'logic', name => 'attach_url');
  my $feedback  = $wizard->create_node( object => $object, module => $node, type => 'page',  name => 'url_feedback');

  ## SET UP CONNECTION BUTTONS
  $wizard->add_connection( from => $warning,  to => $select);
  $wizard->add_connection( from => $select,   to => $attach);
}

1;
