package EnsEMBL::Web::Command::Account::Interface::UserSave;

use strict;
use warnings;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Filter::DuplicateUser;
use EnsEMBL::Web::Tools::RandomString qw(random_string);
use EnsEMBL::Web::Mailer::User;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = '/Account/User';
  my $param; 

  my $interface = $self->interface;
  my $user = $object->user;
  $user = EnsEMBL::Web::Data::User->new unless $user;
  $interface->data($user);
  $interface->cgi_populate($object);

  ## Check input for spam content, etc
  $self->filters(['EmailAddress', 'Spam']);
  my $fail = $self->not_allowed($object);
  if ($fail) { 
    $url .= '/Add';
    $param->{'filter_module'} = $fail->name;
    $param->{'filter_code'} = $fail->error_code;
    $param->{'name'} = $object->param('name');
    $param->{'email'} = $object->param('email');
  }
  else {
    if ($interface->data && $interface->data->id) { ## Update user record
      my $success = $interface->data->save;
      if ($success) {
        $url .= '/Display';
      }
      else {
        $url .= '/Problem';
      }
    }
    else { ## New user
      ## Check for duplicates
      $self->filters(['DuplicateUser']);
      $fail = $self->not_allowed($object);
      if ($fail) { 
        $url .= '/Add';
        $param->{'filter_module'} = $fail->name;
        $param->{'filter_code'} = $fail->error_code;
        $param->{'name'} = $object->param('name');
        $param->{'email'} = $object->param('email');
      }
      else {
        $interface->data->salt(random_string(8));
        $interface->data->status('pending');
        $interface->data->password('');
        my $new_id = $interface->data->save;
        if ($new_id) {
          $url = '/Account/SendActivation';
          $param->{'email'} = $object->param('email');
          $interface->data->created_by($interface->data->id);
          $interface->data->save;
          
          #if subscription request, send blank email to subscription emails
          if ($object->param('subscription') =~ /yes/i) {
            
            my $mailer = EnsEMBL::Web::Mailer::User->new();
            $mailer->send_subscription_email($object->param('email'), $object);
          }
        }
        else {
          $url .= '/Problem';
        }
      }
    }
  }

  $self->ajax_redirect($url, $param);
}

1;
