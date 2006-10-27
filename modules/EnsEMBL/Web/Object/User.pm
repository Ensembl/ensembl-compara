package EnsEMBL::Web::Object::User;

use strict;
use warnings;
no warnings "uninitialized";
use CGI qw(escape);
use CGI::Cookie;

use EnsEMBL::Web::User::Record;

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
  }

  return $self;
}

sub groups {
  ### a
  my $self = shift;
  $Groups_of{$self} = shift if @_;
  return $Groups_of{$self};
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
  my $result = $self->adaptor->add_user((
                                       name => $self->name,
                                       email => $self->email,
                                       password => $self->password,
                                       organisation => $self->organisation,
                                       data => $data
                                    ));
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
  my %details = %{$record};
  if ($details{'user_id'}) { # saving updates to an existing item
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

1;
