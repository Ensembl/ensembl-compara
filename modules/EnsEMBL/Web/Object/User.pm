package EnsEMBL::Web::Object::User;

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);

use EnsEMBL::Web::Record::User;
use EnsEMBL::Web::Object::Group;

our @ISA = qw(EnsEMBL::Web::Record);

{

my %Id_of;
my %Name_of;
my %Email_of;
my %Password_of;
my %Organisation_of;
my %Salt_of;
my %Status_of;
my %Groups_of;
my %Deferred_of;
my %Parameters_of;
my %Is_Populated_of;

sub new {
  ### c
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
  $Parameters_of{$self} = \%params;
  $Id_of{$self} = defined $params{'id'} ? $params{'id'} : "";
  $Name_of{$self} = defined $params{'name'} ? $params{'name'} : "";
  $Email_of{$self} = defined $params{'email'} ? $params{'email'} : "";
  $Password_of{$self} = defined $params{'password'} ? $params{'password'} : "";
  $Organisation_of{$self} = defined $params{'organisation'} ? $params{'organisation'} : "";
  $Groups_of{$self} = defined $params{'groups'} ? $params{'groups'} : [];
  $Salt_of{$self} = defined $params{'salt'} ? $params{'salt'} : '';
  $Status_of{$self} = defined $params{'status'} ? $params{'status'} : "";
  $Deferred_of{$self} = defined $params{'defer'} ? $params{'defer'} : undef;
  $Is_Populated_of{$self} = 0;
  
  if (!$self->adaptor) {
    warn "ADAPTOR not specified";
  }

  ## Flesh out the object from the database 
  if (!$params{'defer'}) {
    $self->populate();
  }

  return $self;
}

sub populate {
  ## Populates the object with data from the database.
  my ($self) = @_;
  if (!$self->is_populated) {
    $self->is_populated(1);
    my %params = %{ $self->parameters };
    if ($params{'id'}) {
#      warn "Populating user with ID: " . $params{'id'};
      my $details = $self->adaptor->find_user_by_user_id($params{'id'}, { adaptor => $self->adaptor });
      $self->assign_fields($details);
      my @records = $self->find_records_by_user_id($params{'id'}, { adaptor => $self->adaptor });
      $self->records(\@records);
      $self->groups($self->find_groups_by_user_id($params{'id'}, { adaptor => $self->adaptor }));
    } elsif ($params{'username'} && $params{'password'}) {
      my $encrypted = $self->encrypt($params{'password'});
      my $details = $self->adaptor->find_user_by_email_and_password(( email => $params{'username'}, 
                                              password => $encrypted, { adaptor => $self->adaptor } ));
     $self->assign_fields($details);
    } elsif ($params{'email'} ) {
       my $details = $self->adaptor->find_user_by_email($params{'email'}, { adaptor => $self->adaptor });
       $self->assign_fields($details);
    }
  }
}

sub load {
  my $self = shift;
  my @records = $self->find_records_by_user_id($self->id, { adaptor => $self->adaptor });
  $self->records(\@records);
}

sub assign_fields {
  my ($self, $details) = @_;
  $Id_of{$self} = $details->{'id'};
  $Name_of{$self} = $details->{'name'};
  $Email_of{$self} = $details->{'email'};
  $Organisation_of{$self} = $details->{'organisation'};
  $Salt_of{$self} = $details->{'salt'};
  $Status_of{$self} = $details->{'status'};
  $Password_of{$self} = $details->{'password'};
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
      #warn "CREATING GROUP " . $group ." for USER " . $self->name;
      #warn "CREATED BY " . $result->{created_by};
      $group->update_users;
      push @{ $return }, $group;
    }
  } 
  return $return;
}

sub find_groups_by_type {
  my ($self, $type) = @_;
  my $results = $self->adaptor->groups_for_type($type);
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
     # warn "CREATING GROUP " . $group ." for USER " . $self->name;
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
  if (!$self->is_populated) { $self->populate; }
  $Groups_of{$self} = shift if @_;
  return $Groups_of{$self};
}

sub find_administratable_groups {
  my $self = shift;
  my @return = ();
  foreach my $group (@{ $self->groups }) {
    if ($self->is_administrator_of($group)) {
      push @return, $group;
    }
  }
  return \@return;
}

sub is_member_of {
  my ($self, $check_group) = @_;
  my $return = 0;
  foreach my $group (@{ $self->groups }) {
    if ($group->id eq $check_group->id) {
      $return = 1;
    }
  }
  return $return;
}

sub is_administrator_of {
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
 # warn "ADDING GROUP: " . $group->name;
  $self->taint('groups');
  push @{ $self->groups }, $group;
}

sub remove_group {
  ### Remove a group from a user
  my ($self, $group) = @_;
  $self->taint('groups');
  $group->remove_user($self);
}

sub name {
  ### a
  my $self = shift;
  if (!$self->is_populated) { $self->populate; }
  $Name_of{$self} = shift if @_;
  if (@_) {
    $self->taint('user');
  }
  return $Name_of{$self};
}

sub status {
  ### a
  my $self = shift;
  if (!$self->is_populated) { $self->populate; }
  $Status_of{$self} = shift if @_;
  if (@_) {
    $self->taint('user');
  }
  return $Status_of{$self};
}

sub id {
  ### a
  my $self = shift;
  $Id_of{$self} = shift if @_;
  return $Id_of{$self};
}

sub salt {
  ### a
  my $self = shift;
  if (!$self->is_populated) { $self->populate; }
  $Salt_of{$self} = shift if @_;
  if (@_) {
    $self->taint('user');
  }
  return $Salt_of{$self};
}

sub defer {
  ### a
  my $self = shift;
  $Deferred_of{$self} = shift if @_;
  return $Deferred_of{$self};
}

sub email {
  ### a
  my $self = shift;
  if (!$self->is_populated) { $self->populate; }
  $Email_of{$self} = shift if @_;
  if (@_) {
    $self->taint('user');
  }
  return $Email_of{$self};
}

sub password {
  ### a
  my $self = shift;
  if (!$self->is_populated) { $self->populate; }
  $Password_of{$self} = shift if @_;
  if (@_) {
    $self->taint('user');
  }
  return $Password_of{$self};
}

sub organisation {
  ### a
  my $self = shift;
  if (!$self->is_populated) { $self->populate; }
  $Organisation_of{$self} = shift if @_;
  if (@_) {
    $self->taint('user');
  }
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
    return $self->parameter_set->cgi->param(@incoming);
  } else {
    return $self->parameter_set->cgi->param;
  }
}

sub prefix {
  my ($self, $value) = @_;
  return undef;
}


sub delete {
  my $self = shift;
  if ($self->id) { 
    warn "DELETING USER: " . $self->id . ", " . $self->name;
    $self->adaptor->delete_user($self->id);
  }
}

sub save {
  my $self = shift;
  my $data = "";
  my $id = $self->id;
  my %params = (
                   name => $self->name,
                   email => $self->email,
                   password => $self->password,
                   status => $self->status,
                   salt => $self->salt,
                   organisation => $self->organisation,
                   data => $data
               );
  #warn "ATTEMPTING SAVE for USER " . $self->name;
  if (!$id) {
    my $result = $self->adaptor->add_user(%params);
  } else {
    #if ($self->tainted->{'user'}) {
      $params{id} = $id;
      #warn "===================== PERFORMING UPDATE";
      my $result = $self->adaptor->update_user((%params));
    #}
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

sub _activation_link {
  my ($user, $site_info) = @_;

  my $link = $site_info->{'base_url'}.'/common/activate?id='.$user->id.'&code='.$user->salt;
  return $link;
}

sub activation_link {
  my ($self) = @_;
  my $link = 'id=' . $self->id . '&code=' . $self->salt;
  return $link;
}

sub web_user_db {
  my $self = shift;
  return $self->adaptor;
}

sub encrypt {
  ### x
  my ($self, $data) = @_;
  return md5_hex($data);
}

sub can {
  ### x
  my ($self, $method) = @_;
  #warn "xxxxxxxxxxxx DEPRECATED FUNCTION xxxxxxxxxxxxxxx";
  my $can = $self->SUPER::can($method);
  if ($method =~ /.*_records/ || $method =~ /find_.*_by/) {
    $can = 1;
  }
  return $can;
}

sub parameters {
  ### a
  my $self = shift;
  $Parameters_of{$self} = shift if @_;
  return $Parameters_of{$self};
}

sub is_populated {
  ### a
  my $self = shift;
  $Is_Populated_of{$self} = shift if @_;
  return $Is_Populated_of{$self};
}

sub DESTROY {
  my $self = shift;
  delete $Id_of{$self};
  delete $Name_of{$self};
  delete $Email_of{$self};
  delete $Password_of{$self};
  delete $Salt_of{$self};
  delete $Organisation_of{$self};
  delete $Status_of{$self};
  delete $Groups_of{$self};
  delete $Deferred_of{$self};
  delete $Parameters_of{$self};
  delete $Is_Populated_of{$self};
}


}


1;
