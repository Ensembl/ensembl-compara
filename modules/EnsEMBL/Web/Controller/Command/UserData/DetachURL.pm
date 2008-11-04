package EnsEMBL::Web::Controller::Command::UserData::DetachURL;

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
    $object->get_session->purge_tmp_data('url');
  }
  $self->ajax_redirect($self->url('/UserData/ManageRemote'));
}

}

1;
