package EnsEMBL::Web::Configuration::UserData;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub populate_tree {
  my $self = shift;

  $self->create_node( 'Upload', "Upload Data",
   [], { 'availability' => 1 }
    );
  $self->create_node( 'Save', "Save Data to Account",
    [qw(save EnsEMBL::Web::Component::UserData::Save
        )],
    { 'availability' => 1, 'concise' => 'Save Data' }
  );
  $self->create_node( 'Manage', "Manage Saved Data",
    [qw(manage EnsEMBL::Web::Component::UserData::Manage
        )],
    { 'availability' => 1, 'concise' => 'Manage Data' }
  );
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

## Interface pages have to be done the 'old-fashioned' way, instead of using Magic

sub user_data {
  my $self   = shift;
  my $object = $self->{'object'};

  my $wizard = $self->wizard;

  ## CREATE NODES
  my $node  = 'EnsEMBL::Web::Wizard::Node::UserData';
  my $start = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'start' ));
  my $upload = $wizard->create_node(( object => $object, module => $node, type => 'logic', name => 'upload'));
  my $feedback = $wizard->create_node(( object => $object, module => $node, type => 'page', name => 'feedback'));

  ## LINK PAGE NODES TOGETHER
  $wizard->add_connection(( from => $start,    to => $upload));
  $wizard->add_connection(( from => $upload,   to => $feedback));

}

1;
