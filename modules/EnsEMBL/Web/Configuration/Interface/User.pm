package EnsEMBL::Web::Configuration::Interface::User;

### Sub-class to do user-specific interface functions

use strict;
use EnsEMBL::Web::Configuration::Interface;
use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::Tools::RandomString;
use EnsEMBL::Web::Tools::Encryption;
use EnsEMBL::Web::Mailer::User;
use EnsEMBL::Web::RegObj;

our @ISA = qw( EnsEMBL::Web::Configuration::Interface );


sub save {
  ### Saves changes to the user record and redirects to a feedback page
  my ($self, $object, $interface) = @_;
  my $script = $object->script;
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
          ## Send activation email here!
          my $mailer = EnsEMBL::Web::Mailer::User->new();
          $mailer->email($user->email);
          $mailer->send_activation_email((
                              'code' => $user->salt || '', 
                              'link' => $user->activation_link || '', 
                              group_id => $object->param('group_id') 
                  ));
          $url = "/common/$script?dataview=success;user_id=".$interface->data->id;
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

sub activate {
  ## Checks that passwords match, are more than 6 characters long and have at least 1 digit
  my ($self, $object, $interface) = @_;
  my $script = $object->script;
  my ($url, $error);
  
  my $pass_1 = $object->param('password'); 
  my $pass_2 = $object->param('confirm_password');
  if ($pass_1 ne $pass_2) {
    $url = "/common/$script?dataview=password_error;error=mismatch";
  }
  elsif (length($pass_1) < 7 || $pass_1 !~ /\d+/ || $pass_1 !~ /[:alpha:]+/) {
    $url = "/common/$script?dataview=password_error;error=insecure";
  }
  else {
    if ($object->param('user_id') && $object->param('salt') && $object->param('password')) {

      $interface->data->populate($object->param('user_id'));
      my $password = $object->param('password');
      my $salt = $interface->data->salt;
      my $encrypted = EnsEMBL::Web::Tools::Encryption::encryptPassword($password, $salt); 
      $interface->data->password($encrypted);
      my $success = $interface->data->save;

      if ($success) {
        $interface->data->status('active');
        $success = $interface->data->save;
      }

      if ($success) {
        $url = "/common/$script?dataview=success;user_id=".$interface->data->id.';key='.$encrypted;
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
