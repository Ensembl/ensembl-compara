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

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user) {
    my $record = undef;
    foreach my $this ($user->sortable_records) {
      $record = $this;
    }

    if (!$record) {
      $record = EnsEMBL::Web::Record::User->new(( adaptor => $ENSEMBL_WEB_REGISTRY->userAdaptor, type => 'sortable', user => $user->id));
    }
    if ($cgi->param('type') =~ /alpha|group/) {
      $record->kind($cgi->param('type'));
      $record->save;
    }
  }

  $cgi->redirect('/common/user/account');
}

}

1;
