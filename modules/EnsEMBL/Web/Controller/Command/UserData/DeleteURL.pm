package EnsEMBL::Web::Controller::Command::UserData::DeleteURL;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::UserData';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;

  my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my $object = $self->create_object;
  if ($object) {
    $object->delete_userurl($cgi->param('id'));
  }
  $self->ajax_redirect($self->url('/UserData/ManageRemote'));
}

}

1;
