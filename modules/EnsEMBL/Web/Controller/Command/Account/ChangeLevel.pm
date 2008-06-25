package EnsEMBL::Web::Controller::Command::Account::ChangeLevel;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Data::Group;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = $self->action->cgi;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Admin', {'group_id' => $cgi->param('group_id')});
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;

  my $group = EnsEMBL::Web::Data::Group->new($cgi->param('group_id'));
  $group->assign_level_to_user($cgi->param('user_id'), $cgi->param('new_level'));

  $cgi->redirect($self->url('/Account/Group', {'id' => $cgi->param('group_id')}) );
}

}

1;
