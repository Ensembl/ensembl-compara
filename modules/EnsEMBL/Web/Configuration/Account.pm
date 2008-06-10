package EnsEMBL::Web::Configuration::Account;

### Configuration for all views based on the Account object, including
### account management 

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub populate_tree {
  my $self = shift;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user && $user->id) {

    $self->create_node( 'Links', "Quick Links",
    [qw(links EnsEMBL::Web::Component::Account::Links
        )],
      { 'availability' => 1 }
    );
    $self->create_node( 'Details', "Your Details",
    [qw(account EnsEMBL::Web::Component::Account::Details
        )],
      { 'availability' => 1 }
    );
    $self->create_node( 'Password', "Change Password",
    [], { 'availability' => 1 }
    );

    my $settings_menu = $self->create_submenu( 'Settings', 'Saved Settings' );
    $settings_menu->append($self->create_node( 'Bookmarks', "Bookmarks ([[counts::bookmarks]])",
    [qw(bookmarks EnsEMBL::Web::Component::Account::Bookmarks
        )],
      { 'availability' => 1, 'concise' => 'Bookmarks' }
    ));
    $settings_menu->append($self->create_node( 'Configurations', "Configurations ([[counts::configurations]])",
    [qw(configs EnsEMBL::Web::Component::Account::Configurations
        )],
      { 'availability' => 1, 'concise' => 'Configurations' }
    ));
    $settings_menu->append($self->create_node( 'Annotations', "Gene Annotations ([[counts::annotations]])",
    [qw(notes EnsEMBL::Web::Component::Account::Annotations
        )],
      { 'availability' => 1, 'concise' => 'Annotations' }
    ));
    $settings_menu->append($self->create_node( 'NewsFilters', "News Filters ([[counts::news_filters]])",
    [qw(new EnsEMBL::Web::Component::Account::NewsFilters
        )],
      { 'availability' => 1, 'concise' => 'News Filters' }
    ));

    my $groups_menu = $self->create_submenu( 'Groups', 'Groups' );

  }
  else {
    $self->create_node( 'Login', "Log in",
    [qw(account EnsEMBL::Web::Component::Account::Login
        )],
      { 'availability' => 1 }
    );
    $self->create_node( 'Register', "Register",
    [qw(account EnsEMBL::Web::Component::Account::Register
        )],
      { 'availability' => 1 }
    );
    $self->create_node( 'LostPassword', "Lost Password",
    [qw(account EnsEMBL::Web::Component::Account::LostPassword
        )],
      { 'availability' => 1 }
    );

  }
}

sub set_default_action {
  my $self = shift;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user && $user->id) {
    $self->{_data}{default} = 'Links';
  }
  else {
    $self->{_data}{default} = 'Login';
  }
}

sub global_context { return $_[0]->_user_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_user_tools;  }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }


#####################################################################################

## Interface pages have to be done the 'old-fashioned' way, instead of using Magic

sub message {
  my $self   = shift;

  if (my $panel = $self->new_panel( 'Image',
    'code'    => "info$self->{flag}",
    'object'  => $self->{object},
    ) ) {
    $self->{object}->command($self->{command});
    $panel->add_components(qw(
        message        EnsEMBL::Web::Component::Account::Message
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
        login       EnsEMBL::Web::Component::Account::Login
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
        login_check       EnsEMBL::Web::Component::Account::LoginCheck
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
        lost_password       EnsEMBL::Web::Component::Account::LostPassword
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
        enter_password        EnsEMBL::Web::Component::Account::Password
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
        update_failed       EnsEMBL::Web::Component::Account::UpdateFailed
    ));

    ## add panel to page
    $self->add_panel( $panel );
  }
}

1;


