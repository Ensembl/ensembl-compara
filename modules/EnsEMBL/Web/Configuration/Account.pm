package EnsEMBL::Web::Configuration::Account;

### Configuration for all views based on the Account object, including
### account management 

use strict;
use EnsEMBL::Web::Configuration;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration );

sub _get_valid_action {
  my $self = shift;
  return $_[0] if $_[0] eq 'SetCookie';
  return $self->SUPER::_get_valid_action( @_ );
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
sub local_tools    { return undef; }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }


sub populate_tree {
  my $self = shift;

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user) {

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
    [qw(password EnsEMBL::Web::Component::Account::Password
      )], 
      { 'availability' => 1 }
    );

    my $settings_menu = $self->create_submenu( 'Settings', 'Manage Saved Settings' );
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
    [qw(news EnsEMBL::Web::Component::Account::NewsFilters
        )],
      { 'availability' => 1, 'concise' => 'News Filters' }
    ));

    my $groups_menu = $self->create_submenu( 'Groups', 'Groups' );
    $groups_menu->append($self->create_node( 'MemberGroups', "Subscriptions ([[counts::member]])",
    [qw(
        groups    EnsEMBL::Web::Component::Account::MemberGroups
        details   EnsEMBL::Web::Component::Account::MemberDetails
        )],
      { 'availability' => 1, 'concise' => 'Subscriptions' }
    ));
    $groups_menu->append($self->create_node( 'AdminGroups', "Administrator ([[counts::admin]])",
    [qw(admingroups EnsEMBL::Web::Component::Account::AdminGroups
        admindetails   EnsEMBL::Web::Component::Account::MemberDetails
        )],
      { 'availability' => 1, 'concise' => 'Administrator' }
    ));


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

  ## Add "invisible" nodes used by interface but not displayed in navigation
  $self->create_node( 'Message', '',
    [qw(message EnsEMBL::Web::Component::Account::Message
        )],
      { 'no_menu_entry' => 1 }
  );
  $self->create_node( 'LoggedIn', '',
    [qw(logged_in EnsEMBL::Web::Component::Account::LoggedIn
        )],
      { 'no_menu_entry' => 1 }
  );
  $self->create_node( 'Logout', "Log Out",
    [],
      { 'no_menu_entry' => 1 }
  );
  $self->create_node( 'UpdateFailed', '',
    [qw(update_failed EnsEMBL::Web::Component::Account::UpdateFailed
        )],
      { 'no_menu_entry' => 1 }
  );
  $self->create_node( 'SelectGroup', '',
    [qw(select_group EnsEMBL::Web::Component::Account::SelectGroup
        )],
      { 'no_menu_entry' => 1 }
  );

}


sub tree_key {
  my $class = shift;
  if ($ENSEMBL_WEB_REGISTRY->get_user) {
    return "::${class}::TREE::USER";
  } else {
    return "::${class}::TREE";
  }
}

1;


