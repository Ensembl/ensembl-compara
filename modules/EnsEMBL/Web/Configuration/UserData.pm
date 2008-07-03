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
sub context_panel  { return $_[0]->_context_panel;  }

sub populate_tree {
  my $self = shift;

  my $uploaded_menu = $self->create_submenu( 'Uploaded', 'Uploaded data' );
  $uploaded_menu->append($self->create_node( 'Upload', "Upload Data",
   [], { 'availability' => 1 }
    ));
  $uploaded_menu->append($self->create_node( 'ShareUpload', "Share Uploaded Data",
    [qw(save_uploaded EnsEMBL::Web::Component::UserData::ShareUpload
        )],
    { 'availability' => 1, 'concise' => 'Share Data' }
  ));
  $uploaded_menu->append($self->create_node( 'SaveUpload', "Save to Account",
    [qw(save_uploaded EnsEMBL::Web::Component::UserData::SaveUpload
        )],
    { 'availability' => 1, 'concise' => 'Save Data' }
  ));
  $uploaded_menu->append($self->create_node( 'ManageUpload', "Manage Saved Data",
    [qw(manage_uploaded EnsEMBL::Web::Component::UserData::ManageUpload
        )],
    { 'availability' => 1, 'concise' => 'Manage Data' }
  ));

  my $attached_menu = $self->create_submenu( 'Attached', 'Remote data' );
  $attached_menu->append($self->create_node( 'Attach', "Attach Data",
   [], { 'availability' => 1 }
    ));
  $attached_menu->append($self->create_node( 'SaveRemote', "Attach to Account",
    [qw(save_remote EnsEMBL::Web::Component::UserData::SaveRemote
        )],
    { 'availability' => 1, 'concise' => 'Save' }
  ));
  $attached_menu->append($self->create_node( 'ManageRemote', "Manage Data",
    [qw(manage_remote EnsEMBL::Web::Component::UserData::ManageRemote
        )],
    { 'availability' => 1, 'concise' => 'Manage Data' }
  ));

  ## Add "invisible" nodes used by interface but not displayed in navigation
  $self->create_node( 'Message', '',
    [qw(message EnsEMBL::Web::Component::UserData::Message
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
  my $node  = 'EnsEMBL::Web::Wizard::Node::UserData';
  #my $session  = $wizard->create_node(( object => $object, module => $node, type => 'logic', name => 'check_session'));
  #my $warning  = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'overwrite_warning' ));
  my $select  = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'select_file' ));
  my $upload  = $wizard->create_node(( object => $object, module => $node, type => 'logic', name => 'upload'));
  my $more    = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'more_input'));
  my $feedback = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'upload_feedback'));

  ## SET UP CONNECTION BUTTONS
  #$wizard->add_connection(( from => $warning,  to => $select));
  $wizard->add_connection(( from => $select,   to => $upload));
  $wizard->add_connection(( from => $upload,   to => $more));
  $wizard->add_connection(( from => $more,     to => $feedback));
}

sub attach {
  my $self   = shift;
  my $object = $self->{'object'};

  my $wizard = $self->wizard;

  ## CREATE NODES
  my $node  = 'EnsEMBL::Web::Wizard::Node::UserData';
  my $server        = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'select_server' ));
  my $source_logic  = $wizard->create_node(( object => $object, module => $node, type => 'logic', name => 'source_logic'));
  my $source        = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'select_source' ));
  my $attach        = $wizard->create_node(( object => $object, module => $node, type => 'logic', name => 'attach'));
  my $feedback      = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'attach_feedback'));

  ## LINK PAGE NODES TOGETHER
  $wizard->add_connection(( from => $server,        to => $source_logic));
  $wizard->add_connection(( from => $source_logic,  to => $source));
  $wizard->add_connection(( from => $source_logic,  to => $attach));
  $wizard->add_connection(( from => $source,        to => $attach));

}

1;
