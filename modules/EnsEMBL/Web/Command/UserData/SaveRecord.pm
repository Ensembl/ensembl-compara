package EnsEMBL::Web::Command::UserData::SaveRecord;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;
  my $url = $object->species_path($object->data_species).'/UserData/ManageData';

  my $user = $object->user;
  my $method = $object->param('accessor');
  my ($record) = $user->$method($object->param('id'));

  if ($object->param('name')) {
    $record->name($object->param('name'));
    $record->save;
  }
 
  $self->ajax_redirect($url); 
}

1;
