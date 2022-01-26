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

package EnsEMBL::Web::ExtIndex;

### Parent class for all external indexers

use strict;
use warnings;

use IO::Socket::INET;
use LWP::UserAgent;
use HTTP::Request;

use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::Exceptions;

use parent qw(EnsEMBL::Web::Root);

sub hub { return shift->{'_hub'}; }

sub new {
  ## @constructor
  my ($class, $hub) = @_;
  return bless {'_hub' => $hub}, $class;
}

sub get_sequence :Abstract {
  ## @abstract
  ## @return Hashref (or list of similar hashrefs for multiple sequences if applicable) with keys:
  ##  - sequence    Fasta format sequence
  ##  - id          ID of the sequence
  ##  - length      Length of the sequence
}

sub get_server {
  ## @protected
  ## Gets the server instance for PFETCH, MFETCH etc
  ## @param Server name
  ## @param Server port
  my ($self, $server_name, $server_port) = @_;

  throw exception('WebException', 'Server not configured') unless $server_name && $server_port;

  my $server = IO::Socket::INET->new(
    PeerAddr  => $server_name,
    PeerPort  => $server_port,
    Proto     => 'tcp',
    Type      => SOCK_STREAM,
    Timeout   => 10
  );

  throw exception('WebException', 'Could not connect to the external db server') unless $server;

  $server->autoflush(1);

  return $server;
}

sub do_http_request {
  ## Make an http requst to the given url
  ## @param Method type (GET or POST)
  ## @param URL to make request to
  my ($self, $method, $service_url) = @_;

  if (!$self->{'_ua'}) {
    $self->{'_ua'} = LWP::UserAgent->new;
    $self->{'_ua'}->proxy([qw(http https)], $_) for $self->hub->web_proxy || ();
  }

  my $response = $self->{'_ua'}->request(HTTP::Request->new($method, $service_url));

  throw exception('WebException', sprintf 'Failed %s request to %s: %s', $method, $service_url, $response->message) if $response->is_error;

  return $response->content;
}

sub output_to_fasta {
  ## @protected
  ## Converts output (list of lines) returned by PFETCH, MFETCH etc to hashref as returned by get_sequence
  my ($self, $id, $lines) = @_;

  @$lines = map { s/^s+|\s+$//gr || () } @$lines;

  return if !@$lines || grep {m/no match/i} @$lines;

  my $fasta = $lines->[0] =~ /^>/ ? [ shift @$lines ] : [ ">$id" ];
  my $seq   = join '', @$lines;

  push @$fasta, $1 while $seq =~ m/(.{1,60})/g;

  return {
    'id'        => $id,
    'length'    => length($seq),
    'sequence'  => join("\n", @$fasta)
  };
}

1;
