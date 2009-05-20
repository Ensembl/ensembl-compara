package EnsEMBL::Web::Command::Interface::Save;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $interface = $object->interface;

  $interface->cgi_populate($object);
  ## Add user ID to new entries in the user/group_record tables
  if (!$object->param('id') && ref($interface->data) =~ /Record/) {
    my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
    $interface->data->user_id($user->id);
  }

  my $success = $interface->data->save;
  my $type;
  if ($success) {
    if (my $custom = $interface->get_landing_page) {
      $type = $custom;
    }
    else {
      $type = 'List';
    }
  }
  else {
    $type = 'Problem';
  }

  my $param = {
    '_referer'  => $object->param('_referer'),
    'x_requested_with'  => $object->param('x_requested_with'),
  };

  my $url = $self->url('/'.$interface->script_name.'/'.$type, $param);
  if ($object->param('x_requested_with')) {
    $self->ajax_redirect($url);
  }
  else {
    $object->redirect($url);
  }
}

}

1;
