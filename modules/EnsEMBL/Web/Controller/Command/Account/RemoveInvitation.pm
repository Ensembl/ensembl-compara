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
  my %params = (
    'id'   => $cgi->param('group_id'),
    '_referer'  => $cgi->param('_referer'),
    'x_requested_with'  => $cgi->param('x_requested_with'),
  );
  $self->ajax_redirect($self->url('/Account/ManageGroup', \%params) );
}

}

1;
