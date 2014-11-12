package EnsEMBL::Web::Tools::RemoteURL;

use strict;
use warnings;

use Exporter qw(import);

our @EXPORT_OK = qw(chase_redirects);

use LWP::UserAgent;

use Data::Dumper;

sub chase_redirects {
  my ($self,$url,$max_follow) = @_;

  $max_follow = 10 unless defined $max_follow;
  my $ua = LWP::UserAgent->new( max_redirect => $max_follow );
  $ua->timeout(10);
  $ua->env_proxy;
  $ua->proxy([qw(http https)], $self->{'hub'}->species_defs->ENSEMBL_WWW_PROXY) || ();
  my $response = $ua->head($url);
  return $response->request->uri->as_string if($response->is_success);
  return undef;
}

1;

