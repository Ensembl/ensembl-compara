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
  $counts->{'bookmarks'}      = $user->bookmarks;
  $counts->{'configurations'} = $user->configurations;
  $counts->{'annotations'}    = $user->annotations;
  $counts->{'news_filters'}   = $user->newsfilters;

  return $counts;
}


1;
