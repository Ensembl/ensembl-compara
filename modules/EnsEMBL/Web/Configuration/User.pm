package EnsEMBL::Web::Configuration::User;

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Wizard::User;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub _add_javascript_libraries {
  ## JS libraries for AJAX bookmark editor
  my $self = shift;
  $self->{page}->javascript->add_source( "/js/prototype.js" );
  $self->{page}->javascript->add_source( "/js/accountview.js" );
}

##-----------------------------------------------------------------------------
## Account management
##-----------------------------------------------------------------------------

sub user_login {
  my $self   = shift;
  my $object = $self->{'object'};
                                                                                
  ## the "user login" wizard uses 4 nodes: enter login details, validate password,
  ## set cookie and return to original page
  my $wizard = EnsEMBL::Web::Wizard::User->new($object);
  $wizard->add_nodes([qw(login validate set_cookie back_to_page)]);
  $wizard->default_node('login');

  $self->_add_javascript_libraries;
                                                                                
  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['login'=>'validate'],
          ['validate'=>'set_cookie'],
          ['set_cookie'=>'back_to_page'],
  ]);

  $self->add_wizard($wizard);
  $self->wizard_panel('Ensembl User Login');
}

sub user_logout {
  my $self   = shift;
  my $object = $self->{'object'};
  
  ## the "user logout" wizard consists of a single node!                                                                              
  my $wizard = EnsEMBL::Web::Wizard::User->new($object);
  $wizard->add_nodes([qw(logout)]);
  $wizard->default_node('logout');
  $self->add_wizard($wizard);
}

sub register {
  my $self = shift;
  my $version = "old";
  if ($version eq "old") {
    $self->hash_register;
  } else {
    $self->command_register;
  }
}

sub command_register {
  my $self = shift;
  my $user = EnsEMBL::Web::Wizard::Data::User(( object => $self->{'object'} ));
  my $wizard = EnsEMBL::Web::Wizard->new(( delegate => $user ));
  
}

sub hash_register {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the user registration wizard uses 6 nodes: enter user data, look up user, preview data,
  ## save data, send account activation link and thanks
  my $wizard = EnsEMBL::Web::Wizard::User->new($object);
                                                    
  $wizard->add_nodes([qw(enter_details lookup_reg preview save_details send_link thanks_reg)]);
  $wizard->default_node('enter_details');

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['enter_details'=>'lookup_reg'],
          ['lookup_reg'=>'preview'],
          ['preview'=>'save_details'],
          ['save_details'=>'send_link'],
          ['send_link'=>'thanks_reg'],
  ]);

  $self->add_wizard($wizard);
  $self->wizard_panel('Ensembl User Registration');
}

sub update_account {
  my $self   = shift;

  my $object = $self->{'object'};

  my $wizard = EnsEMBL::Web::Wizard::User->new($object);
                                                    
  ## the user registration wizard uses 4 nodes: enter data, preview data,
  ## save data and a landing page
  $wizard->add_nodes([qw(enter_details preview save_details accountview)]);
  $wizard->default_node('enter_details');

  $self->_add_javascript_libraries;
                                                                                
  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['enter_details'=>'preview'],
          ['preview'=>'save_details'],
          ['save_details'=>'accountview'],
  ]);

  $self->add_wizard($wizard);
  $self->wizard_panel('Update details');
}

sub set_password {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the password wizard uses 5 nodes: validate, enter new password, compare passwords, 
  ## save password, and accountview
  my $wizard = EnsEMBL::Web::Wizard::User->new($object);
    
  $wizard->add_nodes([qw(validate set_cookie enter_password compare save_password accountview)]);
  $wizard->default_node('enter_password');

  $self->_add_javascript_libraries;
                                                                                
  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['validate'=>'set_cookie'],
          ['set_cookie'=>'enter_password'],
          ['enter_password'=>'compare'],
          ['compare'=>'save_password'],
          ['save_password'=>'accountview'],
  ]);

  $self->add_wizard($wizard);
  $self->wizard_panel('Set Password');
}

sub lost_password {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the lost password wizard uses 5 nodes: enter email, look up user, set password, 
  ## send email and acknowledge
  my $wizard = EnsEMBL::Web::Wizard::User->new($object);
    
  $wizard->add_nodes([qw(enter_email lookup_lost save_password send_link thanks_lost)]);
  $wizard->default_node('enter_email');

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['enter_email'=>'lookup_lost'],
          ['lookup_lost'=>'save_password'],
          ['save_password'=>'send_link'],
          ['send_link'=>'thanks_lost'],
  ]);

  $self->add_wizard($wizard);
  $self->wizard_panel('Lost Password');
}

sub access_denied {
  my $self   = shift;

  if (my $panel1 = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'caption' => 'Access Denied',
    ) ) {
    $panel1->add_components(qw(
        denied        EnsEMBL::Web::Component::User::denied
    ));

    ## add panel to page
    $self->add_panel( $panel1 );
  }
}

sub context_menu {
  my $self = shift;
  my $obj = $self->{object};

  ## this menu clashes with mini one on non-account pages, so remove it
  $self->delete_block('ac_mini');

  ## Is the user logged in?
  my $user_id = $ENV{'ENSEMBL_USER_ID'};

  if ($user_id) {
    my $flag = 'user';
    $self->add_block( $flag, 'bulleted', "Your Ensembl" );


    $self->add_entry( $flag, 'text' => "Account summary",
                                    'href' => "/common/update_account?node=accountview" );
    $self->add_entry( $flag, 'text' => "Update details",
                                    'href' => "/common/update_account" );
    $self->add_entry( $flag, 'text' => "Change password",
                                    'href' => "/common/set_password" );
    $self->add_entry( $flag, 'text' => "Log out",
                                    'href' => "javascript:logout_link()" );
   }
  else {
    my $flag = 'ac_full';
    $self->add_block( $flag, 'bulleted', "Your Ensembl" );

    $self->add_entry( $flag, 'text' => "Login",
                                  'href' => "/common/user_login" );
    $self->add_entry( $flag, 'text' => "Register",
                                  'href' => "/common/register" );
    $self->add_entry( $flag, 'text' => "Lost Password",
                                  'href' => "/common/lost_password" );
    $self->add_entry( $flag, 'text' => "About User Accounts",
                                    'href' => "/info/about/accounts.html" );
  }

}

##--------------------------------------------------------------------------------------------
## Account options
##--------------------------------------------------------------------------------------------

sub add_bookmark {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the add bookmark wizard uses 4 nodes: set name of bookmark, save bookmark 
  ## and return to bookmarked URL, plus accountview as fallback
  my $wizard = EnsEMBL::Web::Wizard::User->new($object);
                                                    
  $self->_add_javascript_libraries;

  $wizard->add_nodes([qw(name_bookmark save_bookmark back_to_page accountview)]);
  $wizard->default_node('accountview'); ## don't want user to access nodes without parameters!

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['name_bookmark'=>'save_bookmark'],
          ['save_bookmark'=>'back_to_page'],
  ]);

  $self->add_wizard($wizard);
  $self->wizard_panel('Bookmarks');
}

sub manage_bookmarks {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the manage bookmark wizard uses 3 nodes: select bookmarks, delete bookmarks 
  ## and accountview
  my $wizard = EnsEMBL::Web::Wizard::User->new($object);
                                                    
  $self->_add_javascript_libraries;

  $wizard->add_nodes([qw(select_bookmarks delete_bookmarks accountview)]);
  $wizard->default_node('select_bookmarks');

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['select_bookmarks'=>'delete_bookmarks'],
          ['delete_bookmarks'=>'accountview'],
  ]);

  $self->add_wizard($wizard);
  $self->wizard_panel('Bookmarks');
}

sub add_config {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the add config wizard uses 4 nodes: set name of config, save config 
  ## and return to configured page, plus accountview as fallback
  my $wizard = EnsEMBL::Web::Wizard::User->new($object);
                                                    
  $self->_add_javascript_libraries;

  $wizard->add_nodes([qw(name_config save_config back_to_page accountview)]);
  $wizard->default_node('accountview'); ## don't want user to access nodes without parameters!

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['name_config'=>'save_config'],
          ['save_config'=>'back_to_page'],
  ]);

  $self->add_wizard($wizard);
  $self->wizard_panel('Saved Configurations');
}

sub manage_configs {
  my $self   = shift;
  my $object = $self->{'object'};

  ## the manage config wizard uses 3 nodes: select configs, delete configs 
  ## and accountview
  my $wizard = EnsEMBL::Web::Wizard::User->new($object);
                                                    
  $self->_add_javascript_libraries;

  $wizard->add_nodes([qw(select_configs delete_configs accountview)]);
  $wizard->default_node('select_configs');

  ## chain the nodes together
  $wizard->add_outgoing_edges([
          ['select_configs'=>'delete_configs'],
          ['delete_configs'=>'accountview'],
  ]);

  $self->add_wizard($wizard);
  $self->wizard_panel('Saved Configurations');
}


1;


