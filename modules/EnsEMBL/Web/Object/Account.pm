package EnsEMBL::Web::Object::Account;

use strict;
use warnings;
use EnsEMBL::Web::Object;
use EnsEMBL::Web::RegObj;


our @ISA = qw(EnsEMBL::Web::Object);

sub caption           {
  my $self = shift;
  return 'Your Account';
}

sub short_caption {
  my $self = shift;
  return 'Account Management';
}

sub counts {
  my $self = shift;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $counts = {};

  if ($user && $user->id) {
    $counts->{'bookmarks'}      = $user->bookmarks->count;
    $counts->{'configurations'} = $user->configurations->count;
    $counts->{'annotations'}    = $user->annotations->count;
    $counts->{'uploads'}        = $user->uploads->count;
    $counts->{'dases'}          = $user->dases->count;
    $counts->{'urls'}           = $user->urls->count;
    my @groups = $user->find_nonadmin_groups;
    foreach my $group (@groups) {
      $counts->{'bookmarks'}      += $group->bookmarks->count;
      $counts->{'configurations'} += $group->configurations->count;
      $counts->{'annotations'}    += $group->annotations->count;
    }

    $counts->{'news_filters'}   = $user->newsfilters->count;
    
    $counts->{'admin'}          = $user->find_administratable_groups;
    $counts->{'member'}         = scalar(@groups);
  }

  return $counts;
}


1;
