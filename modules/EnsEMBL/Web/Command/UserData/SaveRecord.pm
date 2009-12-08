package EnsEMBL::Web::Command::UserData::SaveRecord;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = $object->species_path($object->data_species).'/UserData/ManageData';

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $method = $object->param('accessor');
  my ($record) = $user->$method($object->param('id'));

  if ($object->param('name')) {
    $record->name($object->param('name'));
    $record->save;
  }
 
  $self->ajax_redirect($url, {'_referer' => $object->param('_referer')}); 
}

1;
