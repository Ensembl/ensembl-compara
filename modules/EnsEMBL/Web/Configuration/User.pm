package EnsEMBL::Web::Configuration::User;

### Configuration for all views based on the User object, including
### account management 

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub _add_javascript_libraries {
  ## 'private' method to load commonly-used JS libraries
  my $self = shift;
  $self->{page}->javascript->add_source( "/js/protopacked.js" );  ## Javascript library 
  $self->{page}->javascript->add_source( "/js/accountview42.js" ); ## link magic
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


sub message {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'command' => $self->{command},
    ) ) {
    $panel->add_components(qw(
        message        EnsEMBL::Web::Component::User::message
    ));

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub login {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'caption' => 'Log in',
    ) ) {
    $panel->add_components(qw(
        login       EnsEMBL::Web::Component::User::login
    ));
    $self->add_form($panel, qw(login   EnsEMBL::Web::Component::User::login_form) );

    ## add panel to page
    $self->add_panel( $panel );
  }
}


sub login_check {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'caption' => '',
    ) ) {
    $panel->add_components(qw(
        login_check       EnsEMBL::Web::Component::User::login_check
    ));

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub lost_password {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'caption' => 'Lost password/activation code',
    ) ) {
    $panel->add_components(qw(
        lost_password       EnsEMBL::Web::Component::User::lost_password
    ));
    $self->add_form($panel, qw(lost_password   EnsEMBL::Web::Component::User::lost_password_form) );

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub enter_password {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'caption' => 'Set your password',
    ) ) {
    $panel->add_components(qw(
        enter_password        EnsEMBL::Web::Component::User::enter_password
    ));
    $self->add_form($panel, qw(enter_password   EnsEMBL::Web::Component::User::enter_password_form) );

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub update_failed {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'caption' => 'Database update failed',
    ) ) {
    $panel->add_components(qw(
        update_failed       EnsEMBL::Web::Component::User::update_failed
    ));

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub select_group {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'caption' => 'Select group to share this record with',
    ) ) {
    $panel->add_components(qw(
        select_group        EnsEMBL::Web::Component::User::select_group
    ));
    $self->add_form($panel, qw(select_group   EnsEMBL::Web::Component::User::select_group_form) );

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub accept {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'caption' => 'Accept invitation',
    ) ) {
    $panel->add_components(qw(
        accept        EnsEMBL::Web::Component::User::accept
    ));
    $self->add_form($panel, qw(accept   EnsEMBL::Web::Component::User::accept_form) );

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub invitation_nonpending {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'caption' => 'Invitation Error',
    ) ) {
    $panel->add_components(qw(
        invitation_nonpending       EnsEMBL::Web::Component::User::invitation_nonpending
    ));

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub invitations {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    'caption' => 'Invitations',
    ) ) {
    $panel->add_components(qw(
        invitations       EnsEMBL::Web::Component::User::invitations
    ));

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub context_menu {
  ### General context menu for all user management pages
  my $self = shift;
  my $obj = $self->{object};

  ## this menu clashes with mini one on non-account pages, so remove it
  $self->delete_block('ac_mini');

  ## Is the user logged in?
  my $user_id = $ENV{'ENSEMBL_USER_ID'};

  if ($user_id) {
    my $flag = 'user';
    $self->add_block( $flag, 'bulleted', "Your $SiteDefs::ENSEMBL_SITETYPE" );

    $self->add_entry( $flag, 'text' => "Account summary",
                                    'href' => "/common/user/account" );
    $self->add_entry( $flag, 'text' => "Update details",
                                    'href' => "/common/user/update" );
    $self->add_entry( $flag, 'text' => "Change password",
                                    'href' => "/common/user/reset_password" );
    $self->add_entry( $flag, 'text' => "Log out",
                                    'href' => "javascript:logout_link()" );
  }
  else {
    my $flag = 'ac_full';
    $self->add_block( $flag, 'bulleted', "Your Ensembl" );

    $self->add_entry( $flag, 'text' => "Login",
                                  'href' => "javascript:login_link();" );
    $self->add_entry( $flag, 'text' => "Register",
                                  'href' => "/common/user/register" );
    $self->add_entry( $flag, 'text' => "Lost Password",
                                  'href' => "/common/user/lost_password" );
    $self->add_entry( $flag, 'text' => "About User Accounts",
                                    'href' => "/info/about/accounts.html" );
  }
}

sub groupview {
  my $self   = shift;
  my $user = $self->{'object'};
  
  $self->_add_javascript_libraries;

  if ($user->param('id')) {
    my $group = EnsEMBL::Web::Data::Group->new({ id => $user->param('id') });

    if( my $members_panel = $self->new_panel( 'Image',
      'code'    => "group_details#",
    )) {
      $members_panel->add_components(qw(
        groupview EnsEMBL::Web::Component::User::groupview
      ));
      $self->add_panel($members_panel);
    }

    $self->{page}->set_title('Group: '.$group->name);
  }
  else {
    if( my $members_panel = $self->new_panel( 'Image',
      'code'    => "group_details#",
    )) {
      $members_panel->add_components(qw(
        no_group EnsEMBL::Web::Component::User::no_group
      ));
      $self->add_panel($members_panel);
    }
    $self->{page}->set_title('Group Not Found');
  }

}

sub accountview {
  ### Dynamic view displaying information about a user account
  my $self   = shift;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  $self->_add_javascript_libraries;

  if( my $details_panel = $self->new_panel( 'Image',
    'code'    => "details#",
    'user'    => $user,
    'caption' => 'Account home page for '. $user->name . " (" . $user->email . ")",
  )) {
    $details_panel->add_components(qw(
      account_intro EnsEMBL::Web::Component::User::account_intro
    ));
    $self->add_panel( $details_panel );
  }

  if( my $mixer_panel = $self->new_panel( 'Image',
    'code'    => "mixer#",
    'user'    => $user,
  )) {
    $mixer_panel->add_components(qw(
      settings_mixer EnsEMBL::Web::Component::User::settings_mixer
    ));
    $self->add_panel( $mixer_panel );
  }

  if( my $tabs_panel = $self->new_panel( 'Image',
    'code'    => "user_tabs#",
    'user'    => $user,
  )) {
    $tabs_panel->add_components(qw(
      user_tabs  EnsEMBL::Web::Component::User::user_tabs
    ));
    $self->add_panel( $tabs_panel );
  }

  if( my $prefs_panel = $self->new_panel( 'Image',
    'code'    => "user_prefs#",
    'user'    => $user,
  )) {
    $prefs_panel->add_components(qw(
      user_prefs  EnsEMBL::Web::Component::User::user_prefs
    ));
    $self->add_panel( $prefs_panel );
  }


  $self->{page}->set_title('Account summary: ' . $user->name);
}

1;


