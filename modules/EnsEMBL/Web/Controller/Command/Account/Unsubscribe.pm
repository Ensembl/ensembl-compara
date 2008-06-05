package EnsEMBL::Web::Controller::Command::Account::Unsubscribe;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::Account';

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

  my $group = EnsEMBL::Web::Data::Group->new($cgi->param('id'));
  $group->assign_status_to_user($ENV{'ENSEMBL_USER_ID'}, 'inactive');

  $cgi->redirect($self->url('/Account/Details'));
}

}

1;
