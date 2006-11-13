package EnsEMBL::Web::Document::HTML::UserLinks;

use strict;
use warnings;

use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::DBSQL::UserDB;

{

sub render {
  my $html = "";
  my $user_id = $ENV{'ENSEMBL_USER_ID'};
  if ($user_id > 0) {
    my $user_adaptor = EnsEMBL::Web::DBSQL::UserDB->new();
    my $user = $user_adaptor->find_user_by_user_id($user_id);
    $html .= "Logged in as " . $user->name;
  } else {
    $html .= "Log in or register";
  }
  return $html;
}

}

1;
