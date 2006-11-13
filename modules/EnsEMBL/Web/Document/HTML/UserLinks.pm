package EnsEMBL::Web::Document::HTML::UserLinks;

use strict;
use warnings;

{

sub render {
  my $html = "";
  if ($ENV{'ENSEMBL_USER_ID'}) {
    $html .= "Log in or register";
  } else {
    $html .= "Logged in";
  }
  return $html;
}

}

1;
