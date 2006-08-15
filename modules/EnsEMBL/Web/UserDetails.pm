package EnsEMBL::Web::UserDetails;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);
use CGI::Cookie;

#use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::User;

#our @ISA = qw(EnsEMBL::Web::Object::User);


sub new {
  my ($class, $db, $user_id) = @_;

  ## get data from database
  my $account     = $db->getUserByID($user_id);
  my $groups      = $db->getGroupsByUser($user_id);
  my $bookmarks   = $db->getBookmarksByUser($user_id);

  my $self = {
    'name'      => $$account{'name'},
    'email'     => $$account{'email'},
    'org'       => $$account{'org'},
    'groups'    => $groups,
    'bookmarks' => $bookmarks,
  };
  bless($self, $class);
  return $self;
}


#------------------- ACCESSOR FUNCTIONS -----------------------------


sub get_user_by_email { return $_[0]->web_user_db->getUserByEmail($_[1]); }
sub get_user_by_code  { return $_[0]->web_user_db->getUserByCode($_[1]); }
sub get_user_privilege  { return $_[0]->web_user_db->getUserPrivilege($_[1], $_[2], $_[3]); }

sub reset_password {
  my ($self, $email) = shift;
  return $self->web_user_db->resetPassword($email);
}

sub validate_user { 
  my ($self, $email, $password) = @_;
  return $self->web_user_db->validateUser($email, $password);
}

sub save_user {
  my ($self, $record) = @_;
  my $result;
  my %details = %{$record};
  if ($details{'user_id'}) { # saving updates to an existing item
    $result = $self->web_user_db->updateUserAccount($record);
  }
  else { # inserting a new item into database
    $result = $self->web_user_db->createUserAccount($record);
  }
  return $result;
}

sub set_password { return $_[0]->web_user_db->resetPassword($_[1]); }

sub get_members { return $_[0]->web_user_db->getMembers($_[1]); } 

sub save_bookmark {
  my ($self, $user_id, $url, $title) = @_;
  return $self->web_user_db->saveBookmark($user_id, $url, $title);
}

sub get_bookmarks { return $_[0]->web_user_db->getBookmarksByUser($_[1]); }
sub delete_bookmarks { return $_[0]->web_user_db->deleteBookmarks($_[1]); }

sub get_groups_by_user { return $_[0]->web_user_db->getGroupsByUser($_[1]); }
sub get_groups_by_type { return $_[0]->web_user_db->getGroupsByType($_[1]); }
sub get_all_groups { return $_[0]->web_user_db->getAllGroups; }

1;
