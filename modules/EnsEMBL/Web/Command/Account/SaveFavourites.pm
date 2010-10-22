# $Id$

package EnsEMBL::Web::Command::Account::SaveFavourites;

use strict;

use EnsEMBL::Web::Data::Record::SpeciesList;
use EnsEMBL::Web::Document::HTML::SpeciesList;

use base qw(EnsEMBL::Web::Command);

sub process {
  my $self = shift;
  my $hub  = $self->hub;
  my $user = $hub->user;
  
  my ($species_list) = $user->specieslists;
  $species_list    ||= new EnsEMBL::Web::Data::Record::SpeciesList::User;
    
  $species_list->favourites($hub->param('favourites'));
  $species_list->user_id($user->id);
  $species_list->save;

  print new EnsEMBL::Web::Document::HTML::SpeciesList($hub)->render('fragment');
}

1;
