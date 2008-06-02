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
  ## ensure that this record belongs to the logged-in user!
  my $cgi = new CGI;
  if ($cgi->param('id')) {
    $self->user_or_admin('EnsEMBL::Web::Data::Favourites', $cgi->param('id'), $cgi->param('owner_type'));
  }
}

sub render {
  my ($self, $action) = @_;
  $self->set_action($action);
  if ($self->not_allowed) {
    $self->render_message;
  } else {
    $self->render_page;
  }
}

sub render_page {
  my $self = shift;
  my $user = $self->filters->user;
  $user->specieslists->delete_all;

  $self->filters->redirect($self->url('/index.html'));
}

}

1;
