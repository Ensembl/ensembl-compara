package EnsEMBL::Web::Controller::Command::User::Unsubscribe;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Member', {'group_id' => $cgi->param('id')});

}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->process; 
  }
}

sub process {
  my $self = shift;
  my $cgi = new CGI;
  my $url = '/common/user/account';

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $group = EnsEMBL::Web::Data::Group->new({ id => $cgi->param('id') });
  $group->assign_status_to_user($user, 'inactive');

  $cgi->redirect($url);
}

}

1;
