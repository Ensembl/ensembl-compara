package EnsEMBL::Web::Component::Account::Links;

### Module to create user bookmark list

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Account);
use EnsEMBL::Web::Form;
use EnsEMBL::Web::RegObj;

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

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  
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

=pod
  $html .= qq(</div>

<div class="twocol-right unpadded">
<h3>Page configurations:</h3>
);

  my @configs = $user->configurations;
  my $has_configs = 0;

  if ($#configs > -1) {
    $has_configs = 1;
    $html .= "<dl>\n";
    foreach my $config (@configs) {
      $html .= $self->_output_config($config);
    }
    $html .= "</dl>\n";
  }

  my $group_configs = {};
  foreach my $group (@groups) {
    if ($group->configurations) {
      $has_configs = 1;
      $group_configs->{$group->id}{'group'} = $group;
      my @configs = $group->configurations;
      $group_configs->{$group->id}{'configs'} = \@configs;
    }
  }

  $group_count = keys %$group_configs;
  if ($group_count > 1) {
    foreach my $id (keys %$group_configs) {
    }
  }
  else {
    foreach my $id (keys %$group_configs) {
      $html .= '<h4>From subscribed group "'.$group_configs->{$id}{'group'}->name.'":</h4>';
      my @configs = @{$group_configs->{$id}{'configs'}};
      $html .= "<dl>\n";
      foreach my $config (@configs) {
        $html .= $self->_output_config($config);
      }
      $html .= "</dl>\n";
    }
  }

  if (!$has_configs) {
    $html .= 'You have no saved configurations.'
  }
  $html .= qq(</div>
);

=cut

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

=pod
sub _output_config {
  my ($self, $config) = @_;
  my $html .= '<dt>'.$config->name.'</dt><dd><a href="" class="modal_link"';
  if ($config->description) {
    $html .= ' title="'.$config->description.'"';
  }
  $html .= '>Load&nbsp;into&nbsp;this&nbsp;page</a> | <a href="" class="cp-external"';
  if ($config->description) {
    $html .= ' title="'.$config->description.'"';
  }
  $html .= ">Go&nbsp;to&nbsp;saved&nbsp;page</a></dd>\n";
  return $html;
}
=cut

1;
