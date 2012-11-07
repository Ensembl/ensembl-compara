package EnsEMBL::Web::Command::Account::Interface::GroupSave;

use strict;
use warnings;

use EnsEMBL::Web::Data::Group;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = '/Account/Group';

  my $interface = $object->interface;
  $interface->cgi_populate($object);

  if ($interface->data->id) { ## Update group record
    my $success = $interface->data->save;
    if ($success) {
      $url .= '/List';
    }
    else {
      $url .= '/Problem';
    }
  }
  else { ## New group
    my $new_id = $interface->data->save;
    if ($new_id) {
      $url .= '/List';
      ## Add current user as creator and administrator
      my $group = EnsEMBL::Web::Data::Group->new($new_id);
      my $user = $object->user;
      $group->created_by($user->id);
      $group->save;
      $group->add_user($user, 'administrator');
    }
    else {
      $url .= '/Problem';
    }
  }

  $self->ajax_redirect($url);
}

1;
