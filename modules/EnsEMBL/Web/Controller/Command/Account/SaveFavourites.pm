package EnsEMBL::Web::Controller::Command::Account::SaveFavourites;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Document::HTML::SpeciesList;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Controller::Command::Account';

{

sub BUILD {
  my ($self, $ident, $args) = @_; 
  $self->add_filter('EnsEMBL::Web::Controller::Command::Filter::LoggedIn');
  ## ensure that this record belongs to the logged-in user!
  my $cgi = $self->action->cgi;
  if ($cgi->param('id')) {
    $self->user_or_admin('EnsEMBL::Web::Data::Favourites', $cgi->param('id'), $cgi->param('owner_type'));
  }

}

sub render_page {
  my $self = shift;
  print "Content-type:text/html\n\n";
  my $user = $self->filters->user($EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user->id);

  my ($species_list) = $user->specieslists;
  $species_list = EnsEMBL::Web::Data::Record::SpeciesList::User->new
    unless $species_list;
    
  $species_list->favourites($self->action->cgi->param('favourites'));
  $species_list->list($self->action->cgi->param('list'));
  $species_list->user_id($user->id);
  $species_list->save;

  print EnsEMBL::Web::Document::HTML::SpeciesList->render("fragment");

}

}

1;
