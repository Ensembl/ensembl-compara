package EnsEMBL::Web::Controller::Command::Account::ConfigLanding;

### Module to control where the user ends up after a configuration is saved

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
}

sub process {
  my $self = shift;
  my $cgi = $self->action->cgi;
  my $mode = $cgi->param('mode') || '';
  my $url = $cgi->param('url') || '';

  ## Don't go to config URL if editing/deleting
  if ($mode ne 'add') {
    $url = $self->url('/Account/Details');
  }

  $cgi->redirect($url);
}

}

1;
