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

package EnsEMBL::Web::Object::Phenotype;

use strict;

use base qw(EnsEMBL::Web::Object::Feature);

sub default_action { return 'Locations'; }

sub short_caption {
  my $self = shift;
  my $caption;
  my $name = $self->get_phenotype_desc;
  if (shift eq 'global') {
    $caption = $name ? "Phenotype: $name" : 'Phenotypes';
  }
  else {
    $caption = 'Phenotype-based displays';
  }
  return $caption;
}

sub caption {
  my $self = shift;
  return $self->get_phenotype_desc;
}

sub long_caption {
  my $self = shift;
  $self->has_features ? 'Loci associated with '.$self->get_phenotype_desc 
                      : 'No loci associated with phenotype '.$self->get_phenotype_desc;
}

sub long_caption_2 {
  my $self = shift;
  $self->has_features ? 'Related conditions for '.$self->get_phenotype_desc
                      : 'No features associated with phenotype '.$self->get_phenotype_desc;
}

sub phenotype_id      { $_[0]->{'data'}{'phenotype_id'} = $_[1] if $_[1]; return $_[0]->{'data'}{'phenotype_id'}; }

sub has_features {
  my $self = shift;
  return $self->Obj->{'Variation'} ? 1 : 0;
}

sub get_phenotype_desc {
  my $self = shift;
  my $hub  = $self->hub; 

  if ($hub->param('ph')) {
    my $vardb   = $self->hub->database('variation');
    my $pa      = $vardb->get_adaptor('Phenotype');
    my $p       = $pa->fetch_by_dbID($hub->param('ph'));
    return $p ? $p->description : undef;
  }
  elsif ($hub->param('oa')) {
    my $ontologyterm;
    my $adaptor = $self->hub->get_adaptor('get_OntologyTermAdaptor', 'go');
    my $ontology = $adaptor->fetch_by_accession($hub->param('oa'));
    $ontologyterm = $ontology->name." (".$hub->param('oa').")" if ($ontology);
    return $ontologyterm; 
  }
  return undef;
};

sub get_gene_display_label {
  my ($self, $gene_id) = @_;

  my $gene  = $self->hub->database('core')->get_adaptor('Gene')->fetch_by_stable_id($gene_id);
  my $xref  = $gene && $gene->display_xref;

  return $xref && $xref->display_id || $gene_id;
}

# return underlying Variation API Phenotype object
sub pheno{
  my $self = shift;
  return $self->{_pheno} if $self->{_pheno};
  return unless $self->hub->param('ph');
  my $vardb       = $self->hub->database('variation');
  my $pa          = $vardb->get_adaptor('Phenotype');
  $self->{_pheno} = $pa->fetch_by_dbID($self->hub->param('ph'));
  return $self->{_pheno} ;
}
 

sub get_OntologyTerms{
  my $self = shift;

  return unless $self->hub->param('ph');
  my $vardb   = $self->hub->database('variation');
  my $pa      = $vardb->get_adaptor('Phenotype');
  my $p       = $pa->fetch_by_dbID($self->hub->param('ph'));
  return undef unless defined $p;

  my $ontology_accessions = $p->ontology_accessions();
  my $adaptor = $self->hub->get_adaptor('get_OntologyTermAdaptor', 'go');

  my @ot;
  foreach my $oa (@{$ontology_accessions}){
 
    my $ontologyterm = $adaptor->fetch_by_accession($oa);

    push @ot, $ontologyterm if defined $ontologyterm;
  }

  return (@ot ? \@ot : undef);

}

1;
