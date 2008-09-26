package EnsEMBL::Web::Controller::Command::Blast::Alignment;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Magic qw(stuff);
use base 'EnsEMBL::Web::Controller::Command::Blast';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;
  stuff 'Blast', 'Alignment', $self;
}

}

1;
