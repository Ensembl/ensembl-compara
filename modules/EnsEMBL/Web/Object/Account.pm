package EnsEMBL::Web::Object::Account;

use strict;

use base qw(EnsEMBL::Web::Object);

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
  my $user = $self->user;
  my $counts = {};

  if ($user && $user->id) {
    my @uploads = $self->get_session->get_data('type' => 'upload');
    my @urls    = $self->get_session->get_data('type' => 'url');
    my @groups  = $user->find_nonadmin_groups;
    
    $counts->{'bookmarks'}      = $user->bookmarks->count;
    $counts->{'configurations'} = $user->configurations->count;
    $counts->{'annotations'}    = $user->annotations->count;
    $counts->{'userdata'}       = $user->uploads->count + $user->dases->count + $user->urls->count;
    $counts->{'userdata'}      += @uploads;
    $counts->{'userdata'}      += @urls;
    $counts->{'userdata'}      += scalar keys %{$self->get_session->get_all_das};
    
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
