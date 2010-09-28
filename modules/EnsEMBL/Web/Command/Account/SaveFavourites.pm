package EnsEMBL::Web::Command::Account::SaveFavourites;

use strict;
use warnings;

use EnsEMBL::Web::Data::User;
use EnsEMBL::Web::Document::HTML::SpeciesList;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $user = $self->object->user;
  
  my ($species_list) = $user->specieslists;
  $species_list    ||= new EnsEMBL::Web::Data::Record::SpeciesList::User;
    
  $species_list->favourites($self->object->param('favourites'));
  $species_list->user_id($user->id);
  $species_list->save;

  print EnsEMBL::Web::Document::HTML::SpeciesList->render('fragment');
}

1;
