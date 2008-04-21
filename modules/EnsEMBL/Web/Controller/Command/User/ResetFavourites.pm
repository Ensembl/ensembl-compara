package EnsEMBL::Web::Controller::Command::User::ResetFavourites;

use strict;
use warnings;
use CGI;
use Class::Std;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::Redirect');
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::DataUser');
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->filters->allow) {
    $self->render_page;
  } else {
    $self->render_message;
  }
}

sub render_page {
  my $self = shift;
  my $user = $self->filters->user;
  $user->specieslists->delete_all;

  $self->filters->redirect('/index.html');
}

}

1;
