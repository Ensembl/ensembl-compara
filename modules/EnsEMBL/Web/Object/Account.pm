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
  my $self    = shift;
  my $hub     = $self->hub;
  my $user    = $hub->user;
  my $session = $hub->session;
  my $counts  = {};

  if ($user && $user->id) {
    my @uploads = $session->get_data('type' => 'upload');
    my @urls    = $session->get_data('type' => 'url');
    my @groups  = $user->find_nonadmin_groups;
    
    $counts->{'bookmarks'}      = $user->bookmarks->count;
    $counts->{'configurations'} = $user->configurations->count;
    $counts->{'annotations'}    = $user->annotations->count;
    $counts->{'userdata'}       = $user->uploads->count + $user->dases->count + $user->urls->count;
    $counts->{'userdata'}      += @uploads;
    $counts->{'userdata'}      += @urls;
    $counts->{'userdata'}      += scalar keys %{$session->get_all_das};
    
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
