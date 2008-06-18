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
<div class="twocol-left">
<p>Bookmarks:</p>
);

  my @bookmarks = $user->bookmarks;

  if ($#bookmarks > -1) {
    $html .= "<ul>\n";
    foreach my $bookmark (@bookmarks) {
      $html .= '<li><a href="/Account/_use_bookmark?id='.$bookmark->id.'"';
      if ($bookmark->description) {
        $html .= ' title="'.$bookmark->description.'"';
      }
      $html .= '>'.$bookmark->name."</a></li>\n";
    }
    $html .= "</ul>\n";
  }
  else {
    $html .= 'You have no saved bookmarks.'
  }
  #$html .= qq#<p><a href="javascript:bookmark_link()">Bookmark this page</a></p>#;

  $html .= qq(</div>

<div class="twocol-right">
<p>Page configurations:</p>
);

  my @configs = $user->configurations;

  if ($#configs > -1) {
    $html .= "<ul>\n";
    foreach my $config (@configs) {
      $html .= '<li>'.$config->name.'</li>';
      #$html .= '<li>'.$config->name.' <a href="#" onclick="javascript:go_to_config('.$config->id.');"';
      #if ($config->description) {
      #  $html .= ' title="'.$config->description.'"';
      #}
      #$html .= ">Go to saved page and load tracks</a></li>\n";
    }
    $html .= "</ul>\n";
  }
  else {
    $html .= 'You have no saved configurations.'
  }

  $html .= qq(</div>
);


  return $html;
}

1;
