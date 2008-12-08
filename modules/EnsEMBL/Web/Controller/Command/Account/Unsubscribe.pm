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
  my $cgi = $self->action->cgi;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Member', {'group_id' => $cgi->param('id')});

}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;

  my $group = EnsEMBL::Web::Data::Group->new($cgi->param('id'));
  $group->assign_status_to_user($ENV{'ENSEMBL_USER_ID'}, 'inactive');

  $self->ajax_redirect($self->ajax_url('/Account/MemberGroups', 'reload' => 1));

}

}

1;
