package EnsEMBL::Web::Controller::Command::User::ResetFavourites;

use strict;
use warnings;

use Class::Std;
use CGI;

use EnsEMBL::Web::Data::SpeciesList;
use EnsEMBL::Web::Document::HTML::SpeciesList;

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
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  #warn "RENDERING PAGE for RESET";
  foreach my $list (@{ $user->specieslists }) {
    #warn "LIST: " . $list->id;
    $list->destroy;
  }
  $self->filters->redirect($self->url('/index.html'));
}

}

1;
