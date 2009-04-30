package EnsEMBL::Web::Command::UserData::SaveTempData;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;

  if ($object->param('name')) {
    $object->get_session->set_data('code' => $object->param('code'), 'name' => $object->param('name'));
  }
 
  $self->ajax_redirect(
    '/'.$object->data_species.'/UserData/ManageData', 
    {'_referer' => $object->param('_referer'), 'x_requested_with' => $object->param('x_requested_with')}
  ); 

}

}

1;
