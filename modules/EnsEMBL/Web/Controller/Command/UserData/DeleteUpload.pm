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

  $object->delete_upload
    if $object;

  $self->ajax_redirect($self->ajax_url('/UserData/ManageUpload', 'reload' => 1));
}

}

1;
