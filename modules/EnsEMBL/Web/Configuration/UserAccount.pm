package EnsEMBL::Web::Configuration::UserAccount;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Wizard::UserAccount;

our @ISA = qw( EnsEMBL::Web::Configuration );

##--------------------------------------------------------------------------------------------
## Account management
##--------------------------------------------------------------------------------------------


sub user_login {
  my $self   = shift;
  my $object = $self->{'object'};
                                                                                
  ## the "user login" wizard uses 3 nodes: enter details, check details
  ## and accountview
  my $wizard = EnsEMBL::Web::Wizard::UserAccount->new($object);
  $wizard->add_nodes([qw(login validate accountview)]);
  $wizard->default_node('login');
                                                                                
  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['login'=>'validate'],
          ['validate'=>'accountview'],
  ]);

  $wizard->access_level('user'); 
  $self->add_wizard($wizard);
  $self->wizard_panel('Ensembl User Login');
}

sub user_register {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the user registration wizard uses 5 nodes: enter data, preview data,
  ## check, save data and a landing page
  my $wizard = EnsEMBL::Web::Wizard::UserAccount->new($object);
                                                    
  $wizard->add_nodes([qw(details preview check_new save accountview)]);
  $wizard->default_node('details');

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['details'=>'preview'],
          ['preview'=>'check_new'],
          ['check_new'=>'save'],
          ['save'=>'accountview'],
  ]);

  $wizard->access_level('user'); 
  $self->add_wizard($wizard);
  $self->wizard_panel('Ensembl User Registration');
}

sub user_update {
  my $self   = shift;

  my $object = $self->{'object'};

  my $wizard = EnsEMBL::Web::Wizard::UserAccount->new($object);
                                                    
  ## the user registration wizard uses 4 nodes: enter data, preview data,
  ## save data and a landing page
  $wizard->add_nodes([qw(details preview save accountview)]);
  $wizard->default_node('details');

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['details'=>'preview'],
          ['preview'=>'save'],
          ['save'=>'accountview'],
  ]);

  $wizard->access_level('user'); 
  $self->add_wizard($wizard);
  $self->wizard_panel('Update your details');
}

sub user_pw_change {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the lost password wizard uses 3 nodes: enter new password, save password,
  ## and accountview
  my $wizard = EnsEMBL::Web::Wizard::UserAccount->new($object);
    
  $wizard->add_nodes([qw(new_password save_password accountview)]);
  $wizard->default_node('new_password');

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['new_password'=>'save_password'],
          ['save_password'=>'accountview'],
  ]);

  $wizard->access_level('user'); 
  $self->add_wizard($wizard);
  $self->wizard_panel('Change Password');
}

sub user_pw_lost {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the lost password wizard uses 3 nodes: enter email, send,
  ## and return
  my $wizard = EnsEMBL::Web::Wizard::UserAccount->new($object);
    
  $wizard->add_nodes([qw(lost_password check_old send_link acknowledge)]);
  $wizard->default_node('lost_password');

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['lost_password'=>'check_old'],
          ['check_old'=>'send_link'],
          ['send_link'=>'acknowledge'],
  ]);

  $wizard->access_level('user'); 
  $self->add_wizard($wizard);
  $self->wizard_panel('Lost Password');
}

sub user_pw_reset {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the reset password wizard uses 5 nodes: validate user, change password, save password,
  ## lost password and logout
  my $wizard = EnsEMBL::Web::Wizard::UserAccount->new($object);
    
  $wizard->add_nodes([qw(validate new_password save_password logout lost_password)]);
  $wizard->default_node('validate');

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['validate'=>'new_password'],
          ['validate'=>'lost_password'],
          ['new_password'=>'save_password'],
          ['save_password'=>'logout'],
  ]);

  $wizard->access_level('user'); 
  $self->add_wizard($wizard);
  $self->wizard_panel('Change Password');
}

##--------------------------------------------------------------------------------------------
## Account options
##--------------------------------------------------------------------------------------------

sub user_bookmark {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the bookmark wizard uses 3 nodes: set name of bookmark, save bookmark 
  ## and accountview
  my $wizard = EnsEMBL::Web::Wizard::UserAccount->new($object);
                                                    
  $wizard->add_nodes([qw(name_bookmark save_bookmark accountview)]);
  $wizard->default_node('accountview');

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['name_bookmark'=>'save_bookmark'],
          ['save_bookmark'=>'accountview'],
  ]);

  $wizard->access_level('user'); 
  $self->add_wizard($wizard);
  $self->wizard_panel('Bookmarks');
}

sub user_manage_bkmarks {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the bookmark wizard uses 3 nodes: select bookmarks, delete bookmarks 
  ## and accountview
  my $wizard = EnsEMBL::Web::Wizard::UserAccount->new($object);
                                                    
  $wizard->add_nodes([qw(select_bookmarks delete_bookmarks accountview)]);
  $wizard->default_node('select_bookmarks');

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['select_bookmarks'=>'delete_bookmarks'],
          ['delete_bookmarks'=>'accountview'],
  ]);

  $wizard->access_level('user'); 
  $self->add_wizard($wizard);
  $self->wizard_panel('Bookmarks');
}

sub user_manage_groups {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the bookmark wizard uses 4 nodes: show groups, preview groups, save groups 
  ## and accountview
  my $wizard = EnsEMBL::Web::Wizard::UserAccount->new($object);
                                                    
  $wizard->add_nodes([qw(show_groups preview_groups save_groups accountview)]);
  $wizard->default_node('show_groups');

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['show_groups'=>'preview_groups'],
          ['preview_groups'=>'save_groups'],
          ['save_groups'=>'accountview'],
  ]);

  $wizard->access_level('user'); 
  $self->add_wizard($wizard);
  $self->wizard_panel('Bookmarks');
}

#-----------------------------------------------------------------------

sub access_denied {
  my $self   = shift;

  if (my $panel1 = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'caption' => 'Access Denied',
    ) ) {
    $panel1->add_components(qw(
        denied        EnsEMBL::Web::Component::UserAccount::denied
    ));

    ## add panel to page
    $self->add_panel( $panel1 );
  }
}


1;


