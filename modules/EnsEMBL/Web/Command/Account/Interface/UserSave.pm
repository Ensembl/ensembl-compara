package EnsEMBL::Web::Command::Account::Interface::UserSave;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Filter::Spam;
use EnsEMBL::Web::Filter::DuplicateUser;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = '/Account/User';
  my $param; 

  my $interface = $object->interface;
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
    if ($interface->data->id) { ## Update user record
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
        my $new_id = $interface->data->save;
        if ($new_id) {
          $url = '/Account/SendActivation';
          $param->{'email'} = $object->param('email');
        }
        else {
          $url .= '/Problem';
        }
      }
    }
  }

  if ($object->param('x_requested_with')) {
    $self->ajax_redirect($url, $param);
  }
  else {
    $param->{'_referer'} = $object->param{'_referer');
    $object->redirect($url, $param);
  }
  
}

}

1;
