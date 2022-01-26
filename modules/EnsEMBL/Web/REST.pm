=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::REST;

### Generic interface to a REST API - defaults to Ensembl REST server

use strict;
use warnings;

use JSON qw(from_json to_json);

use EnsEMBL::Web::File::Utils::URL qw(read_file);

sub new {
### c
### @param hub - EnsEMBL::Web::Hub object
### @param server String - base URL of the REST service
  my ($class, $hub, $server, $species_defs) = @_;

  $species_defs ||= $hub->species_defs;
  $server ||= $species_defs->ENSEMBL_REST_URL;
  my $self = { 'hub' => $hub, 'server' => $server, 'species_defs' => $species_defs };
  bless $self, $class;
  return $self;
}

sub hub {
### a
  my $self = shift;
  return $self->{'hub'};
}

sub species_defs { return $_[0]->{'species_defs'}; }

sub server {
### a
  my $self = shift;
  return $self->{'server'};
}

our %content_type = (
                      'json'      => 'application/json',
                      'jsonp'     => 'text/javascript',
                      'fasta'     => 'text/x-fasta',
                      'gff3'      => 'text/x-gff3',
                      'bed'       => 'text/x-bed',
                      'newick'    => 'text/x-nh',
                      'xml'       => 'text/xml',
                      'seqxml'    => 'text/x-seqxml+xml',
                      'phyloxml'  => 'text/x-phyloxml+xml',
                      'yaml'      => 'text/x-yaml',
                    );

sub fetch {
### Fetch data from a given endpoint
### @param endpoint String - any valid REST endpoint, relative to the server base URL
### @param format String (optional) - format to request data as. Defaults to JSON.
### @return - type depends on format requested. Defaults to a hashref which has been
###           converted from json
  my ($self, $endpoint, $args) = @_;

  my $url   = sprintf('%s/%s', $self->server, $endpoint);
  my $delimiter = $args->{url_params}->{_delimiter} || ';';
  delete $args->{'url_params'}->{'_delimiter'};
  if (keys %{$args->{'url_params'}||{}}) {
    $url .= '?';
    while (my($k, $v) = each (%{$args->{'url_params'}||{}})) {
      $url .= sprintf('%s=%s%s', $k, $v, $delimiter);
    }
    delete $args->{'url_params'};
  }
  return $self->fetch_url($url,$args);
}

sub fetch_url {
  my ($self, $url, $args) = @_;
  my $format = delete $args->{'format'} || 'json';
  my $hub   = $self->hub;
  $args->{'hub'} = $hub;

  my $type  = $content_type{lc($format)};
  $args->{'headers'}{'Content-Type'} ||= $type;

  if ($args->{'method'} && $args->{'method'} eq 'post' && $args->{'content'}) {
    my $json = to_json($args->{'content'});
    $args->{'headers'}{'Content'} = $json;
    delete $args->{'content'};
  }

  ## make the request
  my $response = read_file($url, {'nice' => 1, 'no_exception' => 1, %{$args||{}}});
  if ($response->{'error'}) {
    return ($response->{'error'}, 1);
  }
  else {
    if (lc($format) eq 'json') {
      $response = from_json($response->{'content'});
    }
    else {
      $response = $response->{'content'};
    }
    return $response;
  }
}

sub fetch_via_ini {
  my ($self,$species,$name,$params,$args,$part) = @_;

  my $sources = $self->species_defs->get_config($species,'REST_SOURCES') || {};
  return (['Unknown source'], 1) unless $sources->{$name};
  my $type = $sources->{$name};
  my $ini = $self->species_defs->get_config($species,$type);
  return (['Cannot configure for this species'], 1) unless $ini;
  my $url = $ini->{$part||'url'};
  return (['No REST URL'], 1) unless $url;
  { no strict; $url =~ s/<<<(.*?)>>>/${"SiteDefs::$1"}/eg; }
  $url =~ s/<<(.*?)>>/$params->{$1}/eg;
  return $self->fetch_url($url,$args);
}

1;
