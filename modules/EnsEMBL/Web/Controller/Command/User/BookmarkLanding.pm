package EnsEMBL::Web::Controller::Command::User::BookmarkLanding;

### Module to control where the user ends up after a bookmark is saved

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
  if ($self->filters->allow) {
    $self->process;
  } else {
    $self->render_message; 
  }
}

sub process {
  my $self = shift;
  my $cgi = new CGI;
  my $mode = $cgi->param('mode') || '';
  my $url = $cgi->param('url') || '';

  ## Don't go to bookmark URL if adding external link or editing/deleting existing bookmark
  if ($mode ne 'add' || $url !~ /$ENV{'SERVER_NAME'}/) {
    $url = '/common/user/account';
  }

  $cgi->redirect($url);
}

}

1;
