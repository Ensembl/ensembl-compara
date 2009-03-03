package EnsEMBL::Web::Command::Account::SaveFavourites;

use strict;
use warnings;

use Class::Std;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Document::HTML::SpeciesList;
use EnsEMBL::Web::RegObj;

use base 'EnsEMBL::Web::Command';

{

sub process {
  my $self = shift;
  print "Content-type:text/html\n\n";
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  my ($species_list) = $user->specieslists;
  $species_list = EnsEMBL::Web::Data::Record::SpeciesList::User->new
    unless $species_list;
    
  $species_list->favourites($self->object->param('favourites'));
  $species_list->user_id($user->id);
  $species_list->save;

  print EnsEMBL::Web::Document::HTML::SpeciesList->render("fragment");

}

}

1;
