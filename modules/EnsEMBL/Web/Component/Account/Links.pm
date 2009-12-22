package EnsEMBL::Web::Component::Account::Links;

### Module to create user bookmark list

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component::Account);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub caption {
  my $self = shift;
  return undef;
}

sub content {
  my $self = shift;
  my $html;

  my $user = $self->object->user;
  
  $html .= qq(
<!--<div class="twocol-left unpadded">-->
<h3>Bookmarks:</h3>
);

  my @bookmarks = $user->bookmarks;
  my @groups = $user->groups;
  my $has_bookmarks = 0;
  my $bm_check;

  if ($#bookmarks > -1) {
    $has_bookmarks = 1;
    $html .= "<ul>\n";
    foreach my $bookmark (@bookmarks) {
      $bm_check->{$bookmark->url}++;
      $html .= $self->_output_bookmark($bookmark);
    }
    $html .= "</ul>\n";
  }

  my $group_bookmarks = {};
  foreach my $group (@groups) {
    if (my @list = $group->bookmarks) {
      ## Remove any that have the same URL as one of the user's own
      my $ok_bookmarks = $self->dedupe(\@list, $bm_check, 'url');
      next unless scalar(@$ok_bookmarks);
      $has_bookmarks = 1;
      $group_bookmarks->{$group->id}{'group'} = $group;
      $group_bookmarks->{$group->id}{'bookmarks'} = $ok_bookmarks;
    }
  }

  my $group_count = keys %$group_bookmarks;
  if ($group_count > 1) {
    foreach my $id (keys %$group_bookmarks) {
    }
  }
  else {
    foreach my $id (keys %$group_bookmarks) { 
      $html .= '<p><strong>From group "'.$group_bookmarks->{$id}{'group'}->name.'"</strong>:</p>';
      my @bookmarks = @{$group_bookmarks->{$id}{'bookmarks'}};
      $html .= "<ul>\n";
      foreach my $bookmark (@bookmarks) {
        $html .= $self->_output_bookmark($bookmark, $id);
      }
      $html .= "</ul>\n";
    }
  }
  if (!$has_bookmarks) {
    $html .= 'You have no saved bookmarks.'
  }

  return $html;
}

sub _output_bookmark {
  my ($self, $bookmark, $group) = @_;
  my $html .= '<li><a href="/Account/UseBookmark?id='.$bookmark->id;
  if ($group) {
    $html .= ";group=$group";
  }
  $html .= '" class="cp-external"';
  if ($bookmark->description) {
    $html .= ' title="'.$bookmark->description.'"';
  }
  $html .= '>'.$bookmark->name."</a></li>\n";
  return $html;
}

1;
