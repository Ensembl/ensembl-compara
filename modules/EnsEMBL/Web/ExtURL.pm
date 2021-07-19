=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ExtURL;

use strict;
use warnings;
no warnings "uninitialized";

use HTML::Entities qw(encode_entities);
use URI::Escape qw(uri_escape);

# New now takes a secondary hash which contains a list of additional links!
sub new {
  my( $class, $species, $species_defs, %extra_urls ) = @_;
  my $self = { 'species_defs' => $species_defs, 'URLS' => {} };
  bless $self, $class;
  $self->set_species( $species, %extra_urls );
  return $self;
}

sub set_species {
  my( $self, $species, %extra_urls ) = @_;
  $self->{'species'} = $species;
  $self->{'URLS'}{$species} ||= $self->{'species_defs'}->ENSEMBL_EXTERNAL_URLS||{};
  foreach ( keys %extra_urls ) {
    $self->{'URLS'}{$species}{$_} = $extra_urls{$_};
  }
}

sub get_url {
  my ($self, $db, $data, $info_text )=@_;
  eval{
    if((defined($data)) && (not defined($data->{ID})) ){
      $data->{ID} = $data->{primary_id};
    }
  };
  if ($@){
    $data = { 'ID' => $data };
  }
  my $species        = $self->{'species'};
  $data->{'SPECIES'} ||= $species;
  $data->{'DB'}      = $db;
  $data->{'INFO_TEXT'} = $info_text;
## Sets URL to the entry for the given name, OR the default value OTHERWISE returns....
  my $url= $self->{'URLS'}{$species}{ uc($db) } || $self->{'URLS'}{$species}{'DEFAULT'};
  $url =~ s/###(\w+)###/uri_escape( exists $data->{$1} ? $data->{$1} : "(($1))",  "^A-Za-z0-9\-_.!~*'():\/" )/ge;
  return encode_entities($url);
}

sub is_linked{ return exists $_[0]->{'URLS'}{$_[0]->{'species'}}{uc($_[1])}; }

1;
