package EnsEMBL::Web::Controller::Command::Account::UseBookmark;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::User;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;
  if ($cgi->param('id')) {
    $self->user_or_admin('EnsEMBL::Web::Data::Record::Bookmark', $cgi->param('id'), $cgi->param('owner_type'));
  }

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

  my $bookmark;
  if ($cgi->param('owner_type') && $cgi->param('owner_type') eq 'group') {
    $bookmark = EnsEMBL::Web::Data::Record::Bookmark::Group->new($cgi->param('id'));
  }
  else {
    $bookmark = EnsEMBL::Web::Data::Record::Bookmark::User->new($cgi->param('id'));
  }

  my $click = $bookmark->click;
  if ($click) {
    $bookmark->click($click + 1)
  } else {
    $bookmark->click(1);
  }
  $bookmark->save;
  my $url = $bookmark->url;
  if ($url !~ /^http/ && $url !~ /^ftp/) { ## bare addresses of type 'www.domain.com' don't redirect
    $url = 'http://'.$url;
  }
  $cgi->redirect($url);
}

}

1;
