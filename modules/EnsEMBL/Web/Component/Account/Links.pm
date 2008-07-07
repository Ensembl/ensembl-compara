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
<div class="twocol-left unpadded">
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
        $html .= $self->_output_bookmark($bookmark);
      }
      $html .= "</ul>\n";
    }
  }
  if (!$has_bookmarks) {
    $html .= 'You have no saved bookmarks.'
  }

  $html .= qq(</div>

<div class="twocol-right unpadded">
<h3>Page configurations:</h3>
);

  my @configs = $user->configurations;
  my $has_configs = 0;

  if ($#configs > -1) {
    $has_configs = 1;
    $html .= "<ul>\n";
    foreach my $config (@configs) {
      $html .= $self->_output_config($config);
    }
    $html .= "</ul>\n";
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
      $html .= '<p><strong>From subscribed group "'.$group_configs->{$id}{'group'}->name.'"</strong>:</p>';
      my @configs = @{$group_configs->{$id}{'configs'}};
      $html .= "<ul>\n";
      foreach my $config (@configs) {
        $html .= $self->_output_config($config);
      }
      $html .= "</ul>\n";
    }
  }

  if (!$has_configs) {
    $html .= 'You have no saved configurations.'
  }

  $html .= qq(</div>
);


  return $html;
}

sub _output_bookmark {
  my ($self, $bookmark) = @_;
  my $html .= '<li><a href="/Account/UseBookmark?id='.$bookmark->id.'"';
  if ($bookmark->description) {
    $html .= ' title="'.$bookmark->description.'"';
  }
  $html .= '>'.$bookmark->name."</a></li>\n";
  return $html;
}

sub _output_config {
  my ($self, $config) = @_;
  my $html .= '<li>'.$config->name.'</li>';
    #my $html .= '<li>'.$config->name.' <a href="#" onclick="javascript:go_to_config('.$config->id.');"';
    #if ($config->description) {
    #  $html .= ' title="'.$config->description.'"';
    #}
    #$html .= ">Go to saved page and load tracks</a></li>\n";
  return $html;
}
1;
