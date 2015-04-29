package EnsEMBL::Web::Tools::RemoteURL;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(chase_redirects);

use HTTP::Tiny;
use LWP::UserAgent;

sub chase_redirects {
######## DEPRECATED ################
warn "DEPRECATED METHOD 'chase_redirects' - please switch to using EnsEMBL::Web::File::Utils::URL::chase_redirects. This module will be removed in release 80.";
####################################
  my ($self, $url, $max_follow) = @_;

  $max_follow = 10 unless defined $max_follow;

  if ($url =~ /^ftp/) {
    my $ua = LWP::UserAgent->new( max_redirect => $max_follow );
    $ua->timeout(10);
    $ua->env_proxy;
    $ua->proxy([qw(http https)], $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) || ();
    my $response = $ua->head($url);
    return $response->is_success ? $response->request->uri->as_string 
                                    : {'error' => [$response->status_line]};
  }
  else {
    my %args = (
              'timeout'       => 10,
              'max_redirect'  => $max_follow,
              );
    if ($self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) {
      $args{'http_proxy'}   = $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
      $args{'https_proxy'}  = $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY;
    }
    my $http = HTTP::Tiny->new(%args);

    my $response = $http->request('HEAD', $url);
    if ($response->{'success'}) {
      return $response->{'url'};
    }
    else {
      return {'error' => $response->{'status'}.': '.$response->{'reason'}};
    }
  }
}

1;

