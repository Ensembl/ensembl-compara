package EnsEMBL::Web::Controller::Command::Account::RemoveInvitation;

use strict;
use warnings;

use Class::Std;

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
  my $invitation = EnsEMBL::Web::Data::Record::Invite::Group->new($cgi->param('id'));
  $invitation->destroy;
  $cgi->redirect($self->url('/Account/Group', {'id' => $cgi->param('group_id')}) );
}

}

1;
