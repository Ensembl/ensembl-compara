package EnsEMBL::Web::Controller::Command::Help::Glossary;

use strict;
use warnings;

use Class::Std;

use base 'EnsEMBL::Web::Controller::Command';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;
  EnsEMBL::Web::Magic::stuff('Help', 'Glossary', $self, 'Popup');
}

}

1;
