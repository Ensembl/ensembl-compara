package EnsEMBL::Web::Controller::Command::UserData::ShareUpload;

use strict;
use warnings;

use Class::Std;
use EnsEMBL::Web::Document::Wizard;
use base 'EnsEMBL::Web::Controller::Command::UserData';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;
  EnsEMBL::Web::Document::Wizard::simple_wizard('UserData', 'share_upload', $self);
}

}

1;
