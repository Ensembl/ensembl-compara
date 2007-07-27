package EnsEMBL::Web::Controller::Command::User::ChangeStatus;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Object::Data::Invitation;
use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::Object::Group;
use EnsEMBL::Web::RegObj;

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
  my $user = EnsEMBL::Web::Object::User->new({ adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor, id => $cgi->param('user_id') });
  my $group = EnsEMBL::Web::Object::Group->new(( adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor, id => $cgi->param('group_id') ));
  $group->assign_status_to_user($cgi->param('new_status'), $user);
  $group->save;

  $cgi->redirect('/common/user/view_group?id='.$cgi->param('group_id'));
}

}

1;
