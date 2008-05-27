package EnsEMBL::Web::Controller::Command::User::ConfigLanding;

### Module to control where the user ends up after a configuration is saved

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->process; 
  }
}

sub process {
  my $self = shift;
  my $cgi = new CGI;
  my $mode = $cgi->param('mode') || '';
  my $url = $cgi->param('url') || '';

  ## Don't go to config URL if editing/deleting
  if ($mode ne 'add') {
    $url = $self->url('/User/Account');
  }

  $cgi->redirect($url);
}

}

1;
