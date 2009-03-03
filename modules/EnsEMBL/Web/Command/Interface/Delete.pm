package EnsEMBL::Web::Command::Interface::Delete;

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

  my $success;

  if ($interface->permit_delete) {
    $success = $interface->data->destroy;
  }
  else {
    $interface->data->status('inactive');
    $success = $interface->data->save;
  }
  my $type;
  if ($success) {
    $type = 'List';
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
