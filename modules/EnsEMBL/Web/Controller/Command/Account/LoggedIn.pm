package EnsEMBL::Web::Controller::Command::Account::LoggedIn;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;
  EnsEMBL::Web::Magic::stuff('Account', 'LoginCheck', $self, 'Popup');
}

}

1;
