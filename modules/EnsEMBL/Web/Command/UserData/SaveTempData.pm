package EnsEMBL::Web::Command::UserData::SaveTempData;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;
use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  if ($object->param('name')) {
    $object->get_session->set_data('code' => $object->param('code'), 'name' => $object->param('name'));
  }
 
  $self->ajax_redirect(
    $object->species_path($object->data_species).'/UserData/ManageData', 
    {'_referer' => $object->param('_referer')}
  ); 
}

1;
