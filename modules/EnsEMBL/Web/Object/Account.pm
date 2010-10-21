# $Id$

package EnsEMBL::Web::Object::Account;

### NAME: EnsEMBL::Web::Object::Account
### Object for accessing user account information 

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk

### DESCRIPTION
### This module does not wrap around a data object, it merely
### accesses the user object via the session

use strict;

use base qw(EnsEMBL::Web::Object);

sub caption  {
  return 'Your Account';
}

sub short_caption {
  return 'Account Management';
}

sub counts {
  my $self         = shift;
  my $hub          = $self->hub;
  my $user         = $hub->user;
  my $session      = $hub->session;
  my $species_defs = $hub->species_defs;
  my $counts       = {};

  if ($user && $user->id) {
    $counts->{'bookmarks'}      = $user->bookmarks->count;
    $counts->{'configurations'} = $user->configurations->count;
    $counts->{'annotations'}    = $user->annotations->count;
    
    # EnsembleGenomes sites share session and user account - only count data that is attached to species in current site
    $counts->{'userdata'} = 0;
    my @userdata = (
      $session->get_data('type' => 'upload'),
      $session->get_data('type' => 'url'), 
      $session->get_all_das,
      $user->uploads,
      $user->dases, 
      $user->urls
    );
    foreach my $item (@userdata) {
      next unless $item and $species_defs->valid_species(ref ($item) =~ /Record/ ? $item->species : $item->{species});
      $counts->{'userdata'} ++;
    }
    
    my @groups  = $user->find_nonadmin_groups;
    foreach my $group (@groups) {
      $counts->{'bookmarks'}      += $group->bookmarks->count;
      $counts->{'configurations'} += $group->configurations->count;
      $counts->{'annotations'}    += $group->annotations->count;
    }

    $counts->{'news_filters'} = $user->newsfilters->count;
    $counts->{'admin'}        = $user->find_administratable_groups;
    $counts->{'member'}       = scalar(@groups);
  }

  return $counts;
}

1;
