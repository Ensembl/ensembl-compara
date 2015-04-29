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

package EnsEMBL::Web::ExtIndex::ENSEMBL_REST;

### Class to retrieve sequences for given Ensembl ids from REST API

use strict;
use warnings;

use JSON qw(from_json);

use EnsEMBL::Web::Exceptions;

use parent qw(EnsEMBL::Web::ExtIndex);

sub get_sequence {
  ## @param Hashref with following keys:
  ##  - id  Id of the object
  ## @exception If sequence could not be found, or rest api request failed
  my ($self, $params) = @_;

  my $hub = $self->hub;
  my $sd  = $hub->species_defs;
  my $url = $sd->ENSEMBL_REST_URL;

  # invalid id
  throw exception('WebException', "No valid ID provided.")              unless $params->{'id'};
  throw exception('WebException', "$params->{'id'} is not a valid ID.") unless $params->{'id'} =~ /^[a-z]+[0-9]+$/i;

  # make the request
  my $content;
  try {
    $content = from_json($self->do_http_request('GET', "$url/sequence/id/$params->{'id'}?content-type=application/json"));
  } catch {
    throw $_ if $_->type eq 'WebException';
    $content = { 'error' => 'Error parsing REST API response' };
  };

  # REST API returned error or error parsing response
  throw exception('WebException', $content->{'error'}) if $content->{'error'};

  # construct the output sequence
  my $output = $self->output_to_fasta($content->{'desc'} || $content->{'id'}, [ $content->{'seq'} ]);
  $output->{'id'}           = $content->{'id'};
  $output->{'description'}  = $content->{'desc'} if $content->{'desc'};

  return $output;
}

1;
