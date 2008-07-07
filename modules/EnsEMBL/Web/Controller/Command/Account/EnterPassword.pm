package EnsEMBL::Web::Controller::Command::Account::EnterPassword;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Document::Interface;
use EnsEMBL::Web::Interface::InterfaceDef;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $cgi = $self->action->cgi;
  if ($cgi->param('code')) {
    $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::ActivationValid');
  }
  else {
    $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  }
}

sub process {
  my $self = shift;
  EnsEMBL::Web::Magic::stuff('Account', 'Password', $self, 'Popup');
}

}

1;
