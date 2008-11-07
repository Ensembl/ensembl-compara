package EnsEMBL::Web::Controller::Command::UserData::DetachUpload;

use strict;
use warnings;

use Class::Std;
use base 'EnsEMBL::Web::Controller::Command::UserData';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;

  my $object = $self->create_object;
  if ($object) {
    $object->get_session->purge_tmp_data('upload');
  }
  $self->ajax_redirect($self->ajax_url('/UserData/ManageUpload'));
}

}

1;
