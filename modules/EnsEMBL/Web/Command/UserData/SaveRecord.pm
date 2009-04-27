package EnsEMBL::Web::Command::UserData::SaveRecord;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = '/'.$object->data_species.'/UserData/ManageData';

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $method = $object->param('accessor');
  my ($record) = $user->$method($object->param('id'));

  if ($object->param('name')) {
    $record->name($object->param('name'));
    $record->save;
  }
 
  $self->ajax_redirect($url, {'_referer' => $object->param('_referer'), 'x_requested_with' => $object->param('x_requested_with')}); 

}

}

1;
