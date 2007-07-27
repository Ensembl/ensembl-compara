package EnsEMBL::Web::Controller::Command::User::RemoveInvitation;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Object::Data::Invitation;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Admin', {'group_id' => $cgi->param('group_id')});
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
  my $invitation = EnsEMBL::Web::Object::Data::Invitation->new({'id' => $cgi->param('id')});
  $invitation->destroy;
  $cgi->redirect('/common/user/view_group?id='.$cgi->param('group_id'));
}

}

1;
