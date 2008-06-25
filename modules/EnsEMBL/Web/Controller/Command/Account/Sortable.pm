package EnsEMBL::Web::Controller::Command::Account::Sortable;

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
  
  $cgi->redirect($self->url('/Account/Details'));
}

}

1;
