package EnsEMBL::Web::Controller::Command::User::Sortable;

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

  my $kind = ($cgi->param('type') =~ /alpha|group/) 
             ? $cgi->param('type')
             : 'group';
  
  if (my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user) {
    if (my ($record) = $user->sortables) {
      $record->kind($kind);
      $record->save;
    } else {
    $user->add_to_sortables({kind => $kind});
    }
  }
  
  $cgi->redirect('/common/user/account');
}

}

1;
