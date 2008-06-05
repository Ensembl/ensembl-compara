package EnsEMBL::Web::Controller::Command::Account::ChangeStatus;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;
use base 'EnsEMBL::Web::Controller::Command::Account';

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
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->process;
  }
}

sub process {
  warn "*** Processing status change";
  my $self = shift;
  my $cgi = new CGI;
  my $group = EnsEMBL::Web::Data::Group->new($cgi->param('group_id'));
  $group->assign_status_to_user($cgi->param('user_id'), $cgi->param('new_status'));

  $cgi->redirect( $self->url('/Account/Group', {'id' => $cgi->param('group_id')}) );
}

}

1;
