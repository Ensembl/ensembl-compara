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

use base qw(EnsEMBL::Web::Component);

## Retrieve all the ontology accessions associated with a phenotype
sub get_all_ontology_data{

  my $self = shift;

  my %data;

  my $ontologyterms = $self->object->get_OntologyTerms();

  return undef unless defined $ontologyterms;

  foreach my $ot (@{$ontologyterms}){

    ## build link out to Ontology source
    my $acc = $ot->accession();
    next unless $acc;

    $data{$acc}{link}       = $self->external_ontology_link($acc);
    $data{$acc}{name}       = $ot->name();
    $data{$acc}{definition} = (split/\"/, $ot->definition())[1];
  }

  return \%data;
}

## build link out to Ontology source
sub external_ontology {
  my $self = shift;
  my $acc  = shift;
  my $term = shift;

  my $iri_form = $acc;
  $iri_form =~ s/\:/\_/ unless $iri_form =~ /^GO/;

  my $ontology_url = undef;
  $ontology_url = $self->hub->get_ExtURL('EFO',  $iri_form) if $iri_form =~ /^EFO/;
  $ontology_url = $self->hub->get_ExtURL('ORDO', $iri_form) if $iri_form =~ /^Orphanet/;
  $ontology_url = $self->hub->get_ExtURL('HPO',  $iri_form) if $iri_form =~ /^HP/;
  $ontology_url = $self->hub->get_ExtURL('GO',   $iri_form) if $iri_form =~ /^GO/;
  $ontology_url = $self->hub->get_ExtURL('MP',   $iri_form) if $iri_form =~ /^MP/;

  return $ontology_url;
}

sub external_ontology_link{
  my $self = shift;
  my $acc  = shift;
  my $term = shift;

  my $label = ($term) ? $term : $acc;
  my $iri_form = $acc;
  $iri_form =~ s/\:/\_/ unless $iri_form =~ /^GO/;

  my $ontology_link = $acc;
  $ontology_link = $self->hub->get_ExtURL_link( $label, 'EFO',  $iri_form) if $iri_form =~ /^EFO/;
  $ontology_link = $self->hub->get_ExtURL_link( $label, 'ORDO', $iri_form) if $iri_form =~ /^Orphanet/;
  $ontology_link = $self->hub->get_ExtURL_link( $label, 'HPO',  $iri_form) if $iri_form =~ /^HP/;
  $ontology_link = $self->hub->get_ExtURL_link( $label, 'GO',   $iri_form) if $iri_form =~ /^GO/;
  $ontology_link = $self->hub->get_ExtURL_link( $label, 'MP',   $iri_form) if $iri_form =~ /^MP/;

  return $ontology_link;
}

1;
