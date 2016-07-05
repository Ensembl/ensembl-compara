=head1 LICENSE
Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

package EnsEMBL::Web::Component::Phenotype;

use strict;

use base qw(EnsEMBL::Web::Component::Shared);

## build link out to Ontology source
sub external_ontology_link{
  my $self = shift;
  my $acc  = shift;

  my $iri_form = $acc;
  $iri_form =~ s/\:/\_/ unless $acc =~ /^GO/;

  my $ontology_link;
  $ontology_link = $self->hub->get_ExtURL_link( $acc, 'EFO',  $iri_form) if $iri_form =~ /^EFO/;
  $ontology_link = $self->hub->get_ExtURL_link( $acc, 'ORDO', $iri_form) if $iri_form =~ /^Orphanet/;
  $ontology_link = $self->hub->get_ExtURL_link( $acc, 'HPO',  $iri_form) if $iri_form =~ /^HP/;
  $ontology_link = $self->hub->get_ExtURL_link( $acc, 'GO',   $iri_form) if $iri_form =~ /^GO/;

  return $ontology_link;
}

1;
