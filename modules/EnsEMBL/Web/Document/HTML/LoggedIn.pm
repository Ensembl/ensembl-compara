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
  my $url;
  my @params = split(';', $ENV{'QUERY_STRING'});
  foreach my $param (@params) {
    next unless $param =~ '_referer';
    ($url = $param) =~ s/_referer=//;
    last;
  }
  $url = CGI::escape($url);
  if ($user) {
    $html .= sprintf(qq(Logged in as <strong>%s</strong> | <a href="/Account/Logout?_referer=%s">Log out</a>), $user->name, $url);
  }
  else {
    $html .= qq(<a href="/Account/Login?_referer=$url">Login</a> / <a href="/Account/Register?_referer=$url">Register</a>);
  }
  $html .= '</div>';
  $self->print($html);
}

1;
