package EnsEMBL::Web::Controller::Command::Message;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command';

use EnsEMBL::Web::Magic qw(stuff modal_stuff);
{

sub BUILD {
  my ($self, $ident, $args) = @_; 
}

sub process {
  my $self = shift;
    my $cgi = $self->action->cgi;
  if ($cgi->param('no_popup')) {
    stuff $ENV{'ENSEMBL_TYPE'}, 'Message', $self;
  }
  else {
    modal_stuff $ENV{'ENSEMBL_TYPE'}, 'Message', $self, 'Popup';
  }
}

}

1;
