package EnsEMBL::Web::Controller::Command::User::ResetFavourites;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Object::Data::SpeciesList;
use EnsEMBL::Web::Document::HTML::SpeciesList;

use base 'EnsEMBL::Web::Controller::Command::User';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::LoggedIn->new);
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::Redirect->new);
  $self->add_filter(EnsEMBL::Web::Controller::Command::Filter::DataUser->new);
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
  warn "RENDERING PAGE for RESET";
  foreach my $list (@{ $user->specieslists }) {
    warn "LIST: " . $list->id;
    $list->destroy;
  }
  $self->filters->redirect('/index.html');
}

}

1;
