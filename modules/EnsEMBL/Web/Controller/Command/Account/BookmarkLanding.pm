package EnsEMBL::Web::Controller::Command::Account::BookmarkLanding;

### Module to control where the user ends up after a bookmark is saved

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

  ## Don't go to bookmark URL if adding external link or editing/deleting existing bookmark
  if ($mode ne 'add' || $url !~ /$ENV{'SERVER_NAME'}/) {
    $url = $self->url('/Account/Bookmarks');
    if ($cgi->param('_referer')) {
      $url .= '?_referer='.CGI::escape($cgi->param('_referer'));
    }
  }
  $self->ajax_redirect($url);
}

}

1;
