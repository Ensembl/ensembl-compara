package EnsEMBL::Web::Document::HTML::LoggedIn;

use strict;
use warnings;

use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self = shift;
  my $html = qq(<div id="login-status">);
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  if ($user) {
    $html .= 'Logged in as <strong>' . $user->name . '</strong> | <a href="/Account/Logout">Log out</a>';
  }
  else {
    $html .= qq(<a href="/Account/Login">Login</a> / <a href="/Account/Register">Register</a>);
  }
  $html .= '</div>';
  $self->print($html);
}

1;
