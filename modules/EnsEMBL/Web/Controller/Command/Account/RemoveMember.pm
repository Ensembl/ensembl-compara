package EnsEMBL::Web::Controller::Command::Account::RemoveMember;

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
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Admin', {'group_id' => $cgi->param('id')});
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;
  warn "GROUP ".$cgi->param('id').' USER '.$cgi->param('user_id');
  my $membership = EnsEMBL::Web::Data::Membership->find('webgroup_id' => $cgi->param('id'), 'user_id' => $cgi->param('user_id'));
  $membership->destroy;
  my %params = (
    'id'   => $cgi->param('id'),
    '_referer'  => $cgi->param('_referer'),
    'x_requested_with'  => $cgi->param('x_requested_with'),
  );
  $self->ajax_redirect($self->url('/Account/ManageGroup', \%params) );
}

}

1;
