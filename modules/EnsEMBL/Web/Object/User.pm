package EnsEMBL::Web::Object::User;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);
use CGI::Cookie;
use Mail::Mailer;

use EnsEMBL::Web::User::Record;
use EnsEMBL::Web::Object::Group;

our @ISA = qw(EnsEMBL::Web::Record);

{

my %Id_of;
my %Name_of;
my %Email_of;
my %Password_of;
my %Organisation_of;
my %Groups_of;

sub new {
  ### c
  ### TODO: For security Users and Groups should not be pluggable (ie:
  ### they should not inherit from {{EnsEMBL::Web::Proxiable}}).
  ### Need a new class which masks proxability, but still works with
  ### the existing site architecture.
  warn "NEW OBJECT::USER";
  my ($class, $param_hashref) = @_;

  ## Get the params from the hashref sent by the Proxy.
  my %params = ();
  if ($param_hashref->{_object}) {
    %params = %{ $param_hashref->{_object} };
  } else {
    %params = %{ $param_hashref };
  }  

  ## Get blessed object from superclass
  my $self = $class->SUPER::new(%params);

  ## Initialise fields
  $Id_of{$self} = defined $params{'id'} ? $params{'id'} : "";
  $Name_of{$self} = defined $params{'name'} ? $params{'name'} : "";
  $Email_of{$self} = defined $params{'email'} ? $params{'email'} : "";
  $Password_of{$self} = defined $params{'password'} ? $params{'password'} : "";
  $Organisation_of{$self} = defined $params{'organisation'} ? $params{'organisation'} : "";
  $Groups_of{$self} = defined $params{'groups'} ? $params{'groups'} : [];
  
  ## Flesh out the object from the database 
  if ($params{'id'}) {
    my $details = $self->adaptor->getUserByID($params{'id'});
    $Name_of{$self} = $details->{'name'};
    $Email_of{$self} = $details->{'email'};
    $Organisation_of{$self} = $details->{'organisation'};
    my @records = $self->find_records_by_user_id($params{'id'});
    $self->records(\@records);
    $self->groups($self->find_groups_by_user_id($params{'id'}));
  }

  return $self;
}

sub find_groups_by_user_id {
  my ($self, $user_id) = @_;
  my $results = $self->adaptor->groups_for_user_id($user_id);
  my $return = [];
  if ($results) {
    foreach my $result (@{ $results }) {
      my $group = EnsEMBL::Web::Object::Group->new((
                                           adaptor => $self->adaptor,
                                           name => $result->{name},
                                           type => $result->{type},
                                           status => $result->{status},
                                           created_by => $result->{created_by},
                                           modified_by => $result->{modified_by},
                                           created_at => $result->{created_at},
                                           modified_at => $result->{modified_at},
                                           id => $result->{id}
                                             )); 
      warn "CREATING GROUP " . $group ." for USER " . $self->name;
      warn "CREATED BY " . $result->{created_by};
      $group->add_user($self);
      push @{ $return }, $group;
    }
  } 
  return $return;
}

sub find_group_by_group_id {
  my ($self, $group_id) = @_;
  foreach my $group (@{ $self->groups }) {
    if ($group->id == $group_id) {
      return $group;
    }
  }
}

sub groups {
  ### a
  my $self = shift;
  $Groups_of{$self} = shift if @_;
  return $Groups_of{$self};
}

sub is_administrator {
  my ($self, $group) = @_; 
  my $return = 0;
  foreach my $user (@{ $group->administrators }) {
    if ($user->id == $self->id) {
      $return = 1;
    }
  }
  return $return;
}

sub add_group {
  ### Adds a group to the user
  my ($self, $group) = @_;
  my $id = $self->id;
  $group->created_by($id);
  $group->modified_by($id);
  $group->add_user($self);
  warn "ADDING GROUP: " . $group->name;
  $self->taint('groups');
  push @{ $self->groups }, $group;
}

sub name {
  ### a
  my $self = shift;
  $Name_of{$self} = shift if @_;
  return $Name_of{$self};
}

sub id {
  ### a
  my $self = shift;
  $Id_of{$self} = shift if @_;
  return $Id_of{$self};
}

sub email {
  ### a
  my $self = shift;
  $Email_of{$self} = shift if @_;
  return $Email_of{$self};
}

sub password {
  ### a
  my $self = shift;
  $Password_of{$self} = shift if @_;
  return $Password_of{$self};
}

sub organisation {
  ### a
  my $self = shift;
  $Organisation_of{$self} = shift if @_;
  return $Organisation_of{$self};
}

sub param {
  ### a
  ### TODO: This method needs refactoring. Object data classes should
  ### be abstracted from the site definitions. Any essential data
  ### should be passed in as a parameter at instantiation. 
 
  my $self = shift;
  my @incoming = @_;
  if (@incoming) {
    return $self->parameter_set->cgi->param($incoming[0]);
  } else {
    return $self->parameter_set->cgi->param;
  }
}

sub prefix {
  my ($self, $value) = @_;
  return undef;
}

sub save {
  my $self = shift;
  my $data = "";
  my $id = $self->id;
  my %params = (
                   name => $self->name,
                   email => $self->email,
                   password => $self->password,
                   organisation => $self->organisation,
                   data => $data
               );

  if (!$id) {
    my $result = $self->adaptor->add_user(%params);
  } else {
    if ($self->tainted->{'user'}) {
      $params{id} = $id;
      my $result = $self->adaptor->update_user((%params));
    }
  }

  if ($self->tainted->{'groups'}) {
    foreach my $group (@{ $self->groups }) {
      if (ref($group) ne "ARRAY") { 
        $group->modified_by($id);
        $group->save;
      }
    }
  }

}

sub web_user_db {
  my $self = shift;
  return $self->adaptor;
}

sub DESTROY {
  my $self = shift;
  delete $Id_of{$self};
  delete $Name_of{$self};
  delete $Email_of{$self};
  delete $Password_of{$self};
  delete $Organisation_of{$self};
  delete $Groups_of{$self};
}

}


#------------------- ACCESSOR FUNCTIONS -----------------------------

sub user_id   { return $_[0]->get_user_id; }
sub user_name { return $_[0]->Obj->{'user_name'}; }
sub email     { return $_[0]->Obj->{'email'}; }
sub password  { return $_[0]->Obj->{'password'}; }
sub org       { return $_[0]->Obj->{'org'}; }

sub get_user_id {
  my $self = shift;
  my $user_id = $ENV{'ENSEMBL_USER_ID'};

  return $user_id;
}

sub get_user_by_id    { return $_[0]->web_user_db->getUserByID($_[1]); }
sub get_user_by_email { return $_[0]->web_user_db->getUserByEmail($_[1]); }
sub get_user_by_code  { return $_[0]->web_user_db->getUserByCode($_[1]); }

sub validate_user { 
  my ($self, $email, $password) = @_;
  return $self->web_user_db->validateUser($email, $password);
}

sub set_cookie {
  my $self = shift;
  return $self->web_user_db->setUserCookie;
}


sub save_user {
  my ($self, $record) = @_;
  my $result;
  if ($record->{'user_id'}) { # saving updates to an existing item
    $result = $self->web_user_db->updateUserAccount($record);
  }
  else { # inserting a new item into database
    $result = $self->web_user_db->createUserAccount($record);
  }
  return $result;
}

sub set_password { return $_[0]->web_user_db->setPassword($_[1]); }


sub save_bookmark {
  ### Saves a bookmark. Accepts a hashref with the following key-value pairs:
  ### ---
  ### bm_url: The URL to be bookmarked
  ### bm_name: The name of the page to be saved
  ### user_id: The id of the user 
  ### --- 
  my ($self, $params) = @_;
  my $url = $params->{bm_url};
  my $name = $params->{bm_name};
  my $user_id = $params->{user_id};
  my $record = EnsEMBL::Web::User::Record->new(( adaptor => $self->web_user_db ));
  $record->type('bookmark');
  $record->user($user_id); 
  $record->url($url);
  $record->name($name);
  $record->save;
}

sub can {
  my ($self, $method) = @_;
  my $can = $self->SUPER::can($method);
  if ($method =~ /.*_records/ || $method =~ /find_.*_by/) {
    $can = 1;
  }
  return $can;
}

sub get_bookmarks { return $_[0]->web_user_db->getBookmarksByUser($_[1]); }
sub delete_bookmarks { return $_[0]->web_user_db->deleteBookmarks($_[1]); }

sub save_config {
  my ($self, $record) = @_;
  return $self->web_user_db->saveConfig($record);
}

#sub get_configs { return $_[0]->web_user_db->getConfigsByUser($_[1]); }
sub delete_configs { return $_[0]->web_user_db->deleteConfigs($_[1]); }

sub get_groups_by_user { return $_[0]->web_user_db->getGroupsByUser($_[1]); }
sub get_groups_by_type { return $_[0]->web_user_db->getGroupsByType($_[1]); }
sub get_group_by_id    { return $_[0]->web_user_db->getGroupByID($_[1]); }
sub get_membership     { return $_[0]->web_user_db->getMembership($_[1]); }
sub save_membership     { return $_[0]->web_user_db->saveMembership($_[1]); }

sub save_group {
  ### Saves a group
  ### The record has contains the following keys from the wizard:
  ### group_name 
  ### user_id
  ### group_blurb 

  my ($self, $record) = @_;
  my $result;
  if ($record->{'webgroup_id'}) { # saving updates to an existing item
    $result = $self->web_user_db->updateGroup($record);
  }
  else { # inserting a new item into database
    $result = $self->web_user_db->createGroup($record);
  }
  return $result;
}

sub notify_admin {
  my ($self, $record) = @_;

  my $member = $record->{'user_id'};
  my $group  = $record->{'group_id'};

  ## get the admin details for this group
  my $admins = $self->web_user_db->getGroupAdmins($group);
  my $member_name   = $self->user_name;
  my $member_email  = $self->email;
  my $member_org    = $self->org;

  my @mail_attributes = ();
  my @T = localtime();
  my $date = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $T[5]+1900, $T[4]+1, $T[3], $T[2], $T[1], $T[0];
  push @mail_attributes,
    [ 'Date',         $date ],
    [ 'Name',         $member_name ],
    [ 'Email',        $member_email ],
  my $message = '';
  $message .= join "\n", map {sprintf("%-16.16s %s","$_->[0]:",$_->[1])} @mail_attributes;
  $message .= "\n\nComments:\n\n@{[$self->param('comments')]}\n\n";
  my $mailer = new Mail::Mailer 'smtp', Server => "localhost";
  my $sitetype = ucfirst(lc($self->species_defs->ENSEMBL_SITETYPE))||'Ensembl';

  my ($recipient, $count);
  foreach my $adm (@$admins) {
    my $admin_name  = $adm->{'name'};
    my $admin_email = $adm->{'email'};
    $recipient .= "$admin_name <$admin_email>";
    $recipient .= ", " if $count > 0;
    $count++;
  }

  $mailer->open({ 'To' => $recipient, 'Subject' => "$sitetype website Helpdesk", });
  print $mailer $message;
  $mailer->close();
  return 1;

}

1;
