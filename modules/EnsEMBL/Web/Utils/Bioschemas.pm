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

package EnsEMBL::Web::Utils::Bioschemas;

use strict;
use JSON qw(to_json);
use Exporter qw(import);

our @EXPORT = qw(create_bioschema add_species_bioschema);

sub create_bioschema {
  my $data = shift;

  if (ref($data) eq 'ARRAY') {
    foreach (@$data) {
      _munge_bioschema($_);
    }
  }
  elsif (ref($data) eq 'HASH') {
    _munge_bioschema($data);
  }
  else {
    warn "!!! Bioschema data must be a hashref or arrayref of hashrefs";
  }

  #use Data::Dumper;
  #$Data::Dumper::Sortkeys = 1;
  #warn Dumper($data);
  my $markup = qq(
<script type="application/ld+json">
);

  $markup .= to_json($data);

  $markup .= "\n</script>";
  return $markup;
}

sub add_species_bioschema {
## Build bioschema data structure for a species
  my ($species_defs, $data) = @_;

  $data->{'taxonomicRange'} = {
      '@type' => "Taxon",
      'name'  => $species_defs->SPECIES_SCIENTIFIC_NAME,
      'alternateName' => $species_defs->SPECIES_DISPLAY_NAME,
  };

  my $taxon_id = $species_defs->TAXONOMY_ID;
  if ($taxon_id) {
    my $ncbi_url = sprintf '%s/%s', 'http://purl.bioontology.org/ontology/NCBITAXON', $taxon_id;
    my $uniprot_url = sprintf '%s/%s', 'http://purl.uniprot.org/taxonomy', $taxon_id;
    $data->{'taxonomicRange'}{'codeCategory'} = {
                                            '@type'     => 'CategoryCode',
                                            'codeValue' => $taxon_id,
                                            'url'       => $ncbi_url,
                                            'sameAs'    => $uniprot_url,
                                            'inCodeSet' => {
                                                            '@type' => 'CategoryCodeSet',
                                                            'name'  => 'NCBI taxon',
                                                            }
                                            };
    }
}


sub _munge_bioschema {
## Tidy up a bioschema hash and add context
  my $hash = shift;
  return unless ref($hash) eq 'HASH';

  if ($hash->{'type'}) {
    $hash->{'@type'} = $hash->{'type'};
    delete $hash->{'type'};
  }

  ## Use schema.org for DataCatalog/Dataset bc they are generic 
  if ($hash->{'@type'} =~ /^Data/) {
    $hash->{'@context'} = 'http://schema.org';
  }
  else {
    $hash->{'@context'} = 'http://bioschemas.org';
  }
}

1;
