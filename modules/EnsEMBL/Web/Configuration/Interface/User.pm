package EnsEMBL::Web::Configuration::Interface::User;

### Sub-class to do user-specific interface functions

use strict;
use EnsEMBL::Web::Configuration::Interface;
use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::Record::Group;
use EnsEMBL::Web::Object::Data::Invite;
use EnsEMBL::Web::Tools::RandomString;
use EnsEMBL::Web::Tools::Encryption;
use EnsEMBL::Web::Mailer::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration::Interface );


sub save {
  ### Saves changes to the user record and redirects to a feedback page
  my ($self, $object, $interface) = @_;

  my $script = $interface->script_name || $object->script;
  my $url;
  my $primary_key = $interface->data->get_primary_key;
  my $id = $object->param($primary_key);

  if ($object->param('email')) {
    my $user = EnsEMBL::Web::Object::User->new(
                { adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor, 
                  email => $object->param('email') });
    if ($user->id) {
      $url =  "/common/$script?dataview=failure;error=duplicate";
    }
    else {
      $interface->cgi_populate($object, $id);
      if (!$id) {
        $interface->data->salt(EnsEMBL::Web::Tools::RandomString::random_string(8));
      }
      my $success = $interface->data->save;

      if ($success) {
        my $user = EnsEMBL::Web::Object::User->new(
                      { adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor, id => $interface->data->id });
        if (!$user->password) { ## New user
          if ($user->status eq 'pending') {
            ## Send activation email here!
            my $mailer = EnsEMBL::Web::Mailer::User->new();
            $mailer->email($user->email);
            $mailer->send_activation_email((
                              'code' => $user->salt || '', 
                              'link' => $user->activation_link || '', 
                              group_id => $object->param('group_id') 
                  ));
          }
          $url = "/common/$script?dataview=success;user_id=".$interface->data->id.';record_id='.$object->param('record_id');
        }
        else {
          $url = "/common/accountview";
        }
      }
      else {
        $url = "/common/$script?dataview=failure";
      }
    }
  }
  return $url;
}

sub join_by_invite {
  my ($self, $object, $interface) = @_;

  my $record_id = $object->param('record_id');
  #warn "RECORD ID: " . $record_id;
  my @records = EnsEMBL::Web::Record::Group->find_invite_by_group_record_id($record_id, { adaptor => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor });
  my $record = $records[0];
  $record->adaptor($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor);
  my $email = $record->email;

  my $user = EnsEMBL::Web::Object::User->new({ adaptor => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor,  email => $email });

  my $url;
  if ($user->id) {
    my $invite = EnsEMBL::Web::Object::Data::Invite->new({id => $object->param('record_id')});
    my $group_id = $invite->group->id;

    my $group = EnsEMBL::Web::Object::Group->new(( adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor, id => $group_id ));
    # warn "WORKING WITH USER: " . $user->id . ": " . $user->email;
    $user->add_group($group);
    # warn "SAVING USER";
    $user->save;
    $invite->status('accepted');
    # warn "SAVING RECORD";
    $invite->save;
    
    if ($ENV{'ENSEMBL_USER_ID'}) {
      $url = "/common/user/account";
    }
    else {
      $url = '/login.html';
    }
  }
  else {
    $url = "/common/register?email=$email;status=active;record_id=$record_id";
  }
  return $url;
}

sub check_status {
  my ($self, $object, $interface) = @_;

  my $script = $interface->script_name || $object->script;
  my $url;
  my $primary_key = $interface->data->get_primary_key;
  my $id = $object->param($primary_key);

  if ($id) {
    $interface->data->populate($id);
    my $salt = $interface->data->salt;
    ## has this user got pending invites?
    if ($object->param('record_id')) {
      $url = "/common/activate?dataview=confirm;user_id=$id;code=$salt;record_id=".$object->param('record_id');
    }
    else {
      $url = '/common/activate?dataview=deny';
    }
  }
  else {
    $url = '/common/activate?dataview=confirm';
  }
  return $url;
}

sub confirm {
  ### Creates a panel containing a record form populated with data
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'confirm', 'Activate your account')) {
    $panel->add_components(qw(confirm    EnsEMBL::Web::Component::Interface::User::confirm));
    $self->add_form($panel, qw(confirm   EnsEMBL::Web::Component::Interface::User::confirm_form));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Activate your account");
  }
  return undef;
}

sub deny {
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'deny', 'Account Error')) {
    $panel->add_components(qw(deny    EnsEMBL::Web::Component::Interface::User::deny));
    $self->{page}->content->add_panel($panel);
    $self->{page}->set_title("Account already activated");
  }
  return undef;
}

sub password {
  ### Creates a panel containing a record form populated with data
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'password', 'Reset your password')) {
    $panel->add_components(qw(password  EnsEMBL::Web::Component::Interface::User::password));
    $self->add_form($panel, qw(password EnsEMBL::Web::Component::Interface::User::password_form));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Activate your account");
  }
  return undef;
}

sub activate {
  ## Checks that passwords match, are more than 6 characters long and have at least 1 digit
  my ($self, $object, $interface) = @_;
  my $script = $interface->script_name || $object->script;
  my ($url, $error);
  
  my $pass_1 = $object->param('enter_password'); 
  my $pass_2 = $object->param('confirm_password');
  if ($pass_1 ne $pass_2) {
    $url = "/common/$script?dataview=password_error;error=mismatch";
  }
#  elsif (length($pass_1) < 7 || $pass_1 !~ /\d+/ || $pass_1 !~ /[:alpha:]+/) {
#    $url = "/common/$script?dataview=password_error;error=insecure";
#  }
  else {
    if ($object->param('user_id') && $object->param('salt') && $object->param('enter_password')) {
      my %save = %{ $self->update_password($object, $interface) };
      my $success = $save{success};
      if ($success) {
        $interface->data->status('active');
        $success = $interface->data->save;
        ## If this registration was via an invite, add the group to the user
        if ($object->param('record_id')) {
          my $invite = EnsEMBL::Web::Object::Data::Invite->new({id => $object->param('record_id')});
warn "Created object $invite";
          my $group_id = $invite->group->id;
      
          my $user = EnsEMBL::Web::Object::User->new({ adaptor => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor,  
                    id => $object->param('user_id')});
          my $group = EnsEMBL::Web::Object::Group->new(( adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor, id => $group_id ));
          warn "Adding user ", $user->id, " to group ", $group_id;
          # warn "WORKING WITH USER: " . $user->id . ": " . $user->email;
          $user->add_group($group);
          # warn "SAVING USER";
          $user->save;
          $invite->status('accepted');
          # warn "SAVING RECORD";
          $invite->save;
        }
      }

      if ($success) {
        $url = "/common/$script?dataview=success;user_id=".$object->param('user_id').';key='.$save{encrypted_password};
      }
      else {
        $url = "/common/$script?dataview=failure";
      }
    }
    else {
      $url = "/common/$script?dataview=failure";
    }
  }
  return $url; 
}

sub save_password {
  my ($self, $object, $interface) = @_;
  my $script = $interface->script_name || $object->script;
  my %save = %{ $self->update_password($object, $interface) };
  my $success = $save{success};
  my $url = undef;
  if ($success) {
    $url = "/common/$script?dataview=success;id=".$interface->data->id.';code='.$interface->data->salt;
  }
  else {
    $url = "/common/$script?dataview=failure";
  }
  return $url;
}

sub update_password {
  my ($self, $object, $interface) = @_;
  $interface->data->populate($object->param('user_id'));
  my $password = $object->param('enter_password');
  my $salt = $interface->data->salt;
  my $encrypted = EnsEMBL::Web::Tools::Encryption::encryptPassword($password); 
  $interface->data->password($encrypted);
  my $success = $interface->data->save;
  warn "ENC: " . $encrypted;
  warn "SUCCESS: " . $success;
  return { success => $success, encrypted_password => $encrypted };
}

sub password_error {
  my ($self, $object, $interface) = @_;
  if (my $panel = $self->interface_panel($interface, 'error', 'Password Error')) {
    $panel->add_components(qw(error    EnsEMBL::Web::Component::Interface::User::password_error));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Password Error");
  }
  return undef;
}

1;
