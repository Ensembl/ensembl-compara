package EnsEMBL::Web::Document::HTML::UserLinks;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

{

sub render {
  my $html = "";
  if ($user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user) {
    $html .= "Logged in as " . $user->name;
  } else {
    $html .= "Log in or register";
  }
  return $html;
}

}

1;
