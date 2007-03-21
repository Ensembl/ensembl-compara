package EnsEMBL::Web::Tools::Ajax;

use Apache2::RequestUtil;
use CGI;

sub is_enabled {
  my $r = Apache2::RequestUtil->request();
  my %cookies = CGI::Cookie->parse($r->headers_in->{'Cookie'});
  my $ajax = 0;
  if ($cookies{'ENSEMBL_AJAX'} ne 'none' && $cookies{'ENSEMBL_AJAX'} ne '') {
    $ajax = 1;
    warn "AJAX IS AVAILABLE: " . $cookies{'ENSEMBL_AJAX'};
  }
  return $ajax;
}

1;
