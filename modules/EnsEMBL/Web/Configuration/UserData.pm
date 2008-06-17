package EnsEMBL::Web::Configuration::UserData;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub populate_tree {
  my $self = shift;

  my $attached_menu = $self->create_submenu( 'Attached', 'Remote data' );
  $attached_menu->append($self->create_node( 'Attach', "Attach Data",
   [], { 'availability' => 1 }
    ));
  $attached_menu->append($self->create_node( 'SaveAttached', "Attach to Account",
    [qw(save_attached EnsEMBL::Web::Component::UserData::SaveAttached
        )],
    { 'availability' => 1, 'concise' => 'Save' }
  ));
  $attached_menu->append($self->create_node( 'ManageAttached', "Manage Data",
    [qw(manage_attached EnsEMBL::Web::Component::UserData::ManageAttached
        )],
    { 'availability' => 1, 'concise' => 'Manage Data' }
  ));
  my $uploaded_menu = $self->create_submenu( 'Uploaded', 'Uploaded data' );
  $uploaded_menu->append($self->create_node( 'Upload', "Upload Data",
   [], { 'availability' => 1 }
    ));
  $uploaded_menu->append($self->create_node( 'SaveUploaded', "Save to Account",
    [qw(save_uploaded EnsEMBL::Web::Component::UserData::SaveUploaded
        )],
    { 'availability' => 1, 'concise' => 'Save Data' }
  ));
  $uploaded_menu->append($self->create_node( 'ManageUploaded', "Manage Data",
    [qw(manage_uploaded EnsEMBL::Web::Component::UserData::ManageUploaded
        )],
    { 'availability' => 1, 'concise' => 'Manage Data' }
  ));
}

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Upload';
}

sub global_context { return $_[0]->_user_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_user_tools;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }


#####################################################################################

## Wizards have to be done the 'old-fashioned' way, instead of using Magic

sub upload {
  my $self   = shift;
  my $object = $self->{'object'};

  my $wizard = $self->wizard;

  ## CREATE NODES
  my $node  = 'EnsEMBL::Web::Wizard::Node::UserData';
  my $select = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'select_file' ));
  my $upload = $wizard->create_node(( object => $object, module => $node, type => 'logic', name => 'upload'));
  my $feedback = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'upload_feedback'));

  ## LINK PAGE NODES TOGETHER
  $wizard->add_connection(( from => $select,   to => $upload));
  $wizard->add_connection(( from => $upload,   to => $feedback));

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
