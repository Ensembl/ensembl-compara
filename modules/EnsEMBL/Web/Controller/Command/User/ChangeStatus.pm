package EnsEMBL::Web::Controller::Command::User::ChangeStatus;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  warn "*** Building status change";
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Admin', {'group_id' => $cgi->param('group_id')});
}

sub render {
  my ($self, $action) = @_;
  warn "*** Rendering status change";
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->process;
  } else {
    $self->render_message;
  }
}

sub process {
  warn "*** Processing status change";
  my $self = shift;
  my $cgi = new CGI;
  my $user = EnsEMBL::Web::Data::User->new({ id => $cgi->param('user_id') });
  my $group = EnsEMBL::Web::Data::Group->new({ id => $cgi->param('group_id') });
  $group->assign_status_to_user($user, $cgi->param('new_status'));

  $cgi->redirect('/common/user/view_group?id='.$cgi->param('group_id'));
}

}

1;
