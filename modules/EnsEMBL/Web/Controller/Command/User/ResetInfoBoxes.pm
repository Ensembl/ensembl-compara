package EnsEMBL::Web::Controller::Command::User::ResetInfoBoxes;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Object::Data::User;
use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->process;
  } else {
    $self->render_message; 
  }
}

sub process {
  my $self = shift;
  my $cgi = new CGI;

  my $registry_user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $user = EnsEMBL::Web::Object::Data::User->new({ id => $registry_user->id });
  if ($user) {
    foreach my $info_box (@{ $user->infoboxes }) {
      $info_box->destroy;
    }
  }

  $cgi->redirect('/common/user/account');
}

}

1;
