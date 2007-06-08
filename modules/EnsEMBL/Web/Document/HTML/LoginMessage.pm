package EnsEMBL::Web::Document::HTML::LoginMessage;

use strict;
use warnings;

use EnsEMBL::Web::RegObj;

{

sub render {
  my ($class, $request) = @_;
  my $html = "";
  if ($ENV{'ENSEMBL_USER_ID'}) {
    my $user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;

    $html = "<div class='pale boxed' style='padding: 5px;'>\n"; 
    $html .= "<strong>You are logged in as " . $user->name . "</strong>: <a href='/common/user/account'>Account home page</a> &middot; <a href='javascript:logout_link();'>Log out</a>\n";
    $html .= "</div>\n";
  }
  return $html;

}

}

1;
