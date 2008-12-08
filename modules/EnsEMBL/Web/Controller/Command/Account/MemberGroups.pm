package EnsEMBL::Web::Controller::Command::Account::MemberGroups;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::Account';

use EnsEMBL::Web::Magic qw(stuff modal_stuff);

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;
  if ($cgi->param('no_popup')) {
    stuff 'Account', 'MemberGroups', $self;
  }
  else {
    modal_stuff 'Account', 'MemberGroups', $self, 'Popup';
  }
}

}

1;
