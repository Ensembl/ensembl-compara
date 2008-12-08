package EnsEMBL::Web::Controller::Command::Account::LogIn;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::Account';

use EnsEMBL::Web::Magic qw(stuff modal_stuff);
{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;
  if ($cgi->param('no_popup')) {
    stuff 'Account', 'Login', $self;
  }
  else {
    modal_stuff 'Account', 'Login', $self, 'Popup';
  }
}

}

1;
