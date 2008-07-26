package EnsEMBL::Web::Controller::Command::Account::ViewGroup;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::Account';

use EnsEMBL::Web::Magic qw(modal_stuff);

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  ## Only members can view group details
  my $cgi = $self->action->cgi;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Member', {'group_id' => $cgi->param('id')});
}

sub process {
  modal_stuff 'Account', 'Group', $self, 'Popup';
}

}

1;
