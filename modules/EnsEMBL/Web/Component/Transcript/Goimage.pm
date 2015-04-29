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

package EnsEMBL::Web::Component::Transcript::Goimage;

use strict;

use EnsEMBL::Web::Document::Image::Ontology;
use Bio::EnsEMBL::DBSQL::OntologyTermAdaptor;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self                        = shift;
  my $hub                         = $self->hub;
  my $object                      = $self->object;
  my $species_defs                = $hub->species_defs;  

  my %clusters = $species_defs->multiX('ONTOLOGIES');
  return "<p>Ontology database not found.</p>" unless %clusters;

  my $ontology_term_adaptor       = $hub->get_databases('go')->{'go'}->get_GOTermAdaptor;
  
  my $ontovis = EnsEMBL::Web::Document::Image::Ontology->new(
    $hub, undef,
    {'_ontology_term_adaptor' => $ontology_term_adaptor},
  );
  
  my @ontologies;

  foreach my $oid (sort keys %clusters) {
      my $root = $clusters{$oid}->{root};
      push @ontologies, $clusters{$oid}->{db};
      my $url =  $species_defs->ENSEMBL_EXTERNAL_URLS->{$clusters{$oid}->{db}};
      $ontovis->add_cluster_by_parent_accession($root, $url);
  }

  return $self->non_coding_error unless $object->translation_object;
  my $label = 'Ontology';

  # First process GO terms
  my $html;
  my $olist = join '|', @ontologies;

  my $go_hash      = $object->get_go_list($olist);
  my $terms_found = 0;

  my @goslim_subset = ("goslim_generic");
  if (%$go_hash) {
    $html .= sprintf(
      '<p><strong>The chart shows the ancestry of the ontology terms that have been annotated to this entity. <br/>
The nodes are clickable links to the ontology websites. </strong></p>
<p><strong>Key:</strong> <span style="width:20px;padding:4px"> &nbsp; </span> <span style="color:#ffffff;background:%s;padding:4px"> Annotated terms </span> &nbsp;<span style="width:20px">&nbsp;</span>',
      $ontovis->node_fill_colour
    );
    
    #if (%$go_slim_hash) {
    if (@goslim_subset){
      $html .= sprintf(
        ' &nbsp;<span style="border:1px solid %s;padding:4px">Generic GO Slim terms </span>',
        $ontovis->highlighted_border_colour
      )
    }
    
    $html.=  '<br/></p><br/>';
    $terms_found = 1;
  }

  return "<p>No ontology terms have been annotated to this entry.</p>"  unless $terms_found;   

  $ontovis->normal_term_accessions(keys %$go_hash);
  $ontovis->highlighted_subsets(@goslim_subset);
  
  $html .= $ontovis->render;  
  return $html;
}

1;
