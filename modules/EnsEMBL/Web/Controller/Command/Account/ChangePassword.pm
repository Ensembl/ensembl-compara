package EnsEMBL::Web::Controller::Command::Account::ChangePassword;

## Modal version of the password form, used within account maintenance

use strict;
use warnings;

use Class::Std;

use base 'EnsEMBL::Web::Controller::Command::Account';

use EnsEMBL::Web::Magic qw(modal_stuff);

{

sub BUILD {
  my ($self, $ident, $args) = @_;
  my $cgi = $self->action->cgi;
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
}

sub process {
  my $self = shift;
  modal_stuff 'Account', 'ChangePassword', $self, 'Popup';
}

}

1;
