package EnsEMBL::Web::Tools::RemoteURL;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(chase_redirects);

use HTTP::Tiny;

sub chase_redirects {
  my ($self, $url, $max_follow) = @_;

  $max_follow = 10 unless defined $max_follow;

  my %args = (
              'timeout'       => 10,
              'max_redirect'  => $max_follow,
              'http_proxy'    => $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY,
              'https_proxy'   => $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY,
              );

  my $http = HTTP::Tiny->new(%args);

  my $response = $http->request('HEAD', $url);
  if ($response->{'success'}) {
    return $response->{'url'};
  }
  else {
    return {'error' => $response->{'status'}.': '.$response->{'reason'}};
  }
}

1;

