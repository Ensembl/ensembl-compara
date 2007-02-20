package EnsEMBL::Web::Configuration::Interface::User;

### Sub-class to do user-specific interface functions

use strict;
use EnsEMBL::Web::Configuration::Interface;
use EnsEMBL::Web::Object::User;
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
      my $success = 0; #= $interface->data->save;

      if ($success) {
        my $user = EnsEMBL::Web::Object::User->new(
                      { adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor, id => $interface->data->id });
        if (!$user->password) { ## New user
          ## Send activation email here!
          warn "New user saved - time to send the email!";
          my $mailer = EnsEMBL::Web::Mailer::User->new();
          $mailer->email($user->email);
          $mailer->send_activation_email(
                      ( 'code' => $user->salt, 'link' => $user->activation_link, 
                        group_id => $object->param('group_id') ));
          $url = "/common/$script?dataview=success";
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
    $panel->add_components(qw(activate    EnsEMBL::Web::Component::Interface::User::confirm));
    $self->add_form($panel, qw(activate   EnsEMBL::Web::Component::Interface::User::confirm_form));
    $self->{page}->content->add_panel($panel);
    my $type = $object->__objecttype;
    $self->{page}->set_title("Activate your account");
  }
  return undef;
}

sub activate {
   ### Saves activation details to the user record and redirects to a feedback page
  my ($self, $object, $interface) = @_;
  my $script = $object->script;
  my $url;
  
  my $primary_key = $interface->data->get_primary_key;
  my $id = $object->param($primary_key);


}

1;
