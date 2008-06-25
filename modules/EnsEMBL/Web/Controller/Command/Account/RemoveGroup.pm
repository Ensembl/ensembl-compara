package EnsEMBL::Web::Controller::Command::Account::RemoveGroup;

### Module to control where the user ends up after a bookmark is saved

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
  my $group = EnsEMBL::Web::Data::Group->new($cgi->param('id'));
  $group->status('inactive');
  $group->save;
  $cgi->redirect($self->url('/Account/Details'));
}

}

1;
