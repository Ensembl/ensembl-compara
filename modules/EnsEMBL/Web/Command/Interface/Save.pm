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
  my $url = '/'.$interface->script_name.'/';

  my $param = {
    '_referer'  => $object->param('_referer'),
    'x_requested_with'  => $object->param('x_requested_with'),
  };

  $interface->cgi_populate($object);
  ## Add user ID to new entries in the user/group_record tables
  if (!$object->param('id') && ref($interface->data) =~ /Record/) {
    my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
    $interface->data->user_id($user->id);
  }

  my $success = $interface->data->save;
  my $type;
  if ($success) {
    $param->{'id'} = $success;
    if (my $custom = $interface->get_landing_page) {
      $url = $custom;
    }
    else {
      $url .= 'List';
    }
  }
  else {
    $url .= 'Problem';
  }

  if ($object->param('x_requested_with')) {
    $self->ajax_redirect($url, $param);
  }
  else {
    $object->redirect($object->url($url, $param));
  }
}

}

1;
