package EnsEMBL::Web::Controller::Command::UserData::DeleteDAS;

use strict;
use warnings;

use Class::Std;
use base 'EnsEMBL::Web::Controller::Command::UserData';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;

  my $object = $self->create_object;
  if ($object) {
    $object->delete_userdas($cgi->param('id'));
  }
  $self->ajax_redirect($self->ajax_url('/UserData/ManageRemote'));
}

}

1;
