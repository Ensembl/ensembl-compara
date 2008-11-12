package EnsEMBL::Web::Controller::Command::UserData::DeleteUpload;

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
  my $cgi = $self->action->cgi;
  my $object = $self->create_object;

  if ($object) {
    my $type = $object->param('record') || '';
    if ($type eq 'tmp') {
      $object->get_session->purge_tmp_data;
    } elsif ($type eq 'session') {
      $object->get_session->purge_data(type => 'upload');
    } elsif ($type eq 'user') {
      $object->delete_userdata($object->param('id'));
    }
  }
  $self->ajax_redirect($self->ajax_url('/UserData/ManageUpload'));

}

}

1;
