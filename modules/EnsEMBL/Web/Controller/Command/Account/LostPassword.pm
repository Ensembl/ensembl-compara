package EnsEMBL::Web::Controller::Command::Account::LostPassword;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::Account';

use EnsEMBL::Web::Magic qw(modal_stuff);

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;
  modal_stuff 'Account', 'LostPassword', $self, 'Popup';
}

}

1;
