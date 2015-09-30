=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

### Generic interface to the Ensembl REST API 

use strict;
use warnings;

use JSON qw(from_json);

use EnsEMBL::Web::File::Utils::URL qw(read_file);

sub new {
### c
  my ($class, $hub) = @_;
  my $self = { 'hub' => $hub };
  bless $self, $class;
  return $self;
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
  my ($self, $endpoint, $format) = @_;
  $format ||= 'json';

  my $hub   = $self->hub;
  my $url   = sprintf('%s/%s', $hub->species_defs->ENSEMBL_REST_URL, $endpoint);
  my $type  = $content_type{lc($format)};
  $url     .= "?content-type=$type" unless $endpoint =~ /content-type/;

  ## make the request
  my $response = read_file($url);
  unless ($response->{'error'}) {
    if (lc($format) eq 'json') {
      $response = from_json($response->{'content'});
    }
    else {
      $response = $response->{'content'};
    }
  }

  return $response;
}

1;
