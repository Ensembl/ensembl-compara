package EnsEMBL::Web::Configuration::User;

### Configuration for all views based on the User object, including
### account management 

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub populate_tree {
  my $self = shift;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user->id) {

    $self->create_node( 'Account', "Your Details",
    [qw(account EnsEMBL::Web::Component::User::Account
        )],
      { 'availability' => 1, 'concise' => 'Your Details' }
    );
    $self->create_node( 'Bookmarks', "Bookmarks",
    [qw(bookmarks EnsEMBL::Web::Component::User::Bookmarks
        )],
      { 'availability' => 1 }
    );
    $self->create_node( 'Configurations', "Configurations",
    [qw(configs EnsEMBL::Web::Component::User::Configurations
        )],
      { 'availability' => 1 }
    );
    $self->create_node( 'Gene Annotations', "Gene Annotations",
    [qw(notes EnsEMBL::Web::Component::User::Annotations
        )],
      { 'availability' => 1 }
    );
    $self->create_node( 'News Filters', "News Filters",
    [qw(new EnsEMBL::Web::Component::User::NewsFilters
        )],
      { 'availability' => 1 }
    );

  }
}

sub set_default_action {
  my $self = shift;
  $self->{_data}{default} = 'Login';
}

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

sub message {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    ) ) {
    $self->{object}->command($self->{command});
    $panel->add_components(qw(
        message        EnsEMBL::Web::Component::User::Message
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
    ) ) {
    $panel->add_components(qw(
        login       EnsEMBL::Web::Component::User::Login
    ));

    ## add panel to page
    $self->add_panel( $panel );
  }
}


sub login_check {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    ) ) {
    $panel->add_components(qw(
        login_check       EnsEMBL::Web::Component::User::LoginCheck
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
    ) ) {
    $panel->add_components(qw(
        lost_password       EnsEMBL::Web::Component::User::LostPassword
    ));

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub enter_password {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    ) ) {
    $panel->add_components(qw(
        enter_password        EnsEMBL::Web::Component::User::EnterPassword
    ));

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub update_failed {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    ) ) {
    $panel->add_components(qw(
        update_failed       EnsEMBL::Web::Component::User::UpdateFailed
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
    ) ) {
    $panel->add_components(qw(
        select_group        EnsEMBL::Web::Component::User::SelectGroup
    ));

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub accept {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    ) ) {
    $panel->add_components(qw(
        accept        EnsEMBL::Web::Component::User::Accept
    ));

    ## add panel to page
    $self->add_panel( $panel );
  }
}

sub invitation_nonpending {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    ) ) {
    $panel->add_components(qw(
        invitation_nonpending       EnsEMBL::Web::Component::User::InvitationNonpending
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
    ) ) {
    $panel->add_components(qw(
        invitations       EnsEMBL::Web::Component::User::Invitations
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
                                    'href' => "/User/Account" );
    $self->add_entry( $flag, 'text' => "Update details",
                                    'href' => "/User/Update" );
    $self->add_entry( $flag, 'text' => "Change password",
                                    'href' => "/User/Password" );
    $self->add_entry( $flag, 'text' => "Log out",
                                    'href' => "javascript:logout_link()" );
  }
  else {
    my $flag = 'ac_full';
    $self->add_block( $flag, 'bulleted', "Your Ensembl" );

    $self->add_entry( $flag, 'text' => "Login",
                                  'href' => "javascript:login_link();" );
    $self->add_entry( $flag, 'text' => "Register",
                                  'href' => "/User/Register" );
    $self->add_entry( $flag, 'text' => "Lost Password",
                                  'href' => "/User/LostPassword" );
    $self->add_entry( $flag, 'text' => "About User Accounts",
                                    'href' => "/info/about/accounts.html" );
  }
}

sub groupview {
  my $self   = shift;
  my $user = $self->{'object'};
  
  $self->_add_javascript_libraries;

  if ($user->param('id')) {
    my $group = EnsEMBL::Web::Data::Group->new($user->param('id'));

    if( my $members_panel = $self->new_panel('Image', 'code'    => "group_details#")) {
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


