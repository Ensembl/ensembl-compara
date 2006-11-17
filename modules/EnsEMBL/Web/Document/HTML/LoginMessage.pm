package EnsEMBL::Web::Document::HTML::LoginMessage;

use strict;
use warnings;

use EnsEMBL::Web::Object::User;

{

sub render {
  my ($class, $request) = @_;
  my $html = "";
  if ($ENV{'ENSEMBL_USER_ID'}) {
    my $user = EnsEMBL::Web::Object::User->new({ id => $ENV{'ENSEMBL_USER_ID'} });
    $html = "<div class='pale boxed' style='padding: 5px;'>\n"; 
    $html .= "<b>You are logged in as " . $user->name . ".</b> Go to your <a href='/account'>account</a> or <a href='javascript:logout_link();'>log out.</a>\n";
    $html .= "</div>\n";
  }
  return $html;

}

}

1;
