package EnsEMBL::Web::Document::HTML::UserLinks;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

{

sub render {
  my $html = "";
  my $user_id = $ENV{'ENSEMBL_USER_ID'};
  if ($user_id > 0) {
    my $user_adaptor = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->userAdaptor;
    my $user = $user_adaptor->find_user_by_user_id($user_id);
    $html .= "Logged in as " . $user->name;
  } else {
    $html .= "Log in or register";
  }
  return $html;
}

}

1;
