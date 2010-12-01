package EnsEMBL::Web::Command::UserData::DeleteUpload;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $object = $self->object;

  my $node = $self->hub->param('goto') || 'ManageData';

  $object->delete_upload
    if $object;

  $self->ajax_redirect($object->species_path($object->data_species).'/UserData/'.$node, {'reload' => 1});
}

1;
