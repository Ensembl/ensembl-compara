package EnsEMBL::Web::Controller::Command::User::Sortable;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::RegObj;
use EnsEMBL::Web::Data::Sortable;

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

  if (my $user = $ENSEMBL_WEB_REGISTRY->get_user) {
    my $record = $user->sortables->[0];

    $record ||= EnsEMBL::Web::Data::Sortable->new;
    $record->user_id($user->id);

    if ($cgi->param('type') =~ /alpha|group/) {
      $record->kind($cgi->param('type'));
      $record->save;
    }
  }

  $cgi->redirect($self->url('/User/Account'));
}

}

1;
