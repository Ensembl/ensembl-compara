package EnsEMBL::Web::Controller::Command::Account::ManageGroup;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::Account';

use EnsEMBL::Web::Magic qw(modal_stuff);

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  my $cgi = $self->action->cgi;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Admin', {'group_id' => $cgi->param('id')});
}

sub process {
  my $self = shift;
  modal_stuff 'Account', 'ManageGroup', $self, 'Popup';
}

}

1;
