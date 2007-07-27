package EnsEMBL::Web::Controller::Command::User::UseBookmark;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Object::Data::Bookmark;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  my $cgi = new CGI;
  my $record;
  if ($cgi->param('id')) {
    $self->user_or_admin('EnsEMBL::Web::Object::Data::Bookmark', $cgi->param('id'), $cgi->param('record_type'));
  }

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

  my $bookmark = EnsEMBL::Web::Object::Data::Bookmark->new({'id' => $cgi->param('id') });

  my $click = $bookmark->click;
  if ($click) {
    $bookmark->click($click + 1)
  } else {
    $bookmark->click(1);
  }
  $bookmark->save;

  $cgi->redirect($bookmark->url);
}

}

1;
