package EnsEMBL::Web::Document::HTML::UserLinks;

use strict;
use warnings;

{

sub render {
  my $html = "";
  my $user_id = $ENV{'ENSEMBL_USER_ID'};
  if ($user_id > 0) {
    $html .= "Logged in";
  } else {
    $html .= "Log in or register";
  }
  return $html;
}

}

1;
