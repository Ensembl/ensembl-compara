package EnsEMBL::Web::Controller::Command::UserData::ManageUpload;

use strict;
use warnings;

use Class::Std;
use base 'EnsEMBL::Web::Controller::Command::UserData';
use EnsEMBL::Web::Magic qw(modal_stuff);

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;
   modal_stuff 'UserData', 'ManageUpload', $self, 'Popup';
}

}

1;
