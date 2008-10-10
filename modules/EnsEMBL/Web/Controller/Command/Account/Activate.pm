package EnsEMBL::Web::Controller::Command::Account::Activate;

## Module to wrap the non-modal version of the password form

use strict;
use warnings;

use Class::Std;

use base 'EnsEMBL::Web::Controller::Command::Account';

use EnsEMBL::Web::Magic qw(stuff);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $cgi = $self->action->cgi;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::ActivationValid');
}

sub process {
  my $self = shift;
  stuff 'Account', 'Activate', $self, 'Popup';
}

}

1;
