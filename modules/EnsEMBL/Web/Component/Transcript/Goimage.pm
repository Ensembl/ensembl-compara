# $Id$

package EnsEMBL::Web::Component::Transcript::Goimage;

use strict;

use EnsEMBL::Web::Tools::OntologyVisualisation;

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
  my $ontology_term_adaptor       = $hub->get_databases('go')->{'go'}->get_GOTermAdaptor;
  my $go_sub_dir                  = '/GO/';  
  my $go_dir                      = $species_defs->ENSEMBL_TMP_DIR_IMG . $go_sub_dir;
  my $go_url                      = '../../../' . $species_defs->ENSEMBL_TMP_URL_IMG . $go_sub_dir;
  my $go_id_url                   = $species_defs->ENSEMBL_EXTERNAL_URLS->{'GO'};
  my $get_relation_type_colour    = sub { return $species_defs->colour('goimage', shift); };
  my $image_background_colour     = $species_defs->colour('goimage', 'image_background');
  my $node_fill_colour            = $species_defs->colour('goimage', 'node_fill');
  my $node_font_colour            = $species_defs->colour('goimage', 'node_font');
  my $node_border_colour          = $species_defs->colour('goimage', 'node_border');
  my $non_highlight_fill_colour   = $species_defs->colour('goimage', 'non_highlight_fill');
  my $non_highlight_font_colour   = $species_defs->colour('goimage', 'non_highlight_font');
  my $non_highlight_border_colour = $species_defs->colour('goimage', 'non_highlight_border');    
  my $goslim_goa_fill             = $species_defs->colour('goimage', 'goslim_goa_fill');
  my $goslim_goa_font             = $species_defs->colour('goimage', 'goslim_goa_font');
  my $goslim_goa_border           = $species_defs->colour('goimage', 'goslim_goa_border');
  my $node_fill_text              = $species_defs->colour('goimage', 'node_fill_text');
  my $goslim_goa_fill_text        = $species_defs->colour('goimage', 'goslim_goa_fill_text');
  $node_fill_text                 =~ s/_/ /g;
  $goslim_goa_fill_text           =~ s/_/ /g;
  
  my $ontovis = new EnsEMBL::Web::Tools::OntologyVisualisation(
    $ontology_term_adaptor,
    $go_dir,
    $go_url,
    $go_id_url,
    $image_background_colour,
    $node_fill_colour,
    $node_font_colour,
    $node_border_colour,
    $non_highlight_fill_colour,
    $non_highlight_font_colour,
    $non_highlight_border_colour,
    $goslim_goa_fill,
    $goslim_goa_font,
    $goslim_goa_border,
    $get_relation_type_colour
  );
  
  $ontovis->add_cluster_by_parent_accession('GO:0005575');
  $ontovis->add_cluster_by_parent_accession('GO:0008150');
  $ontovis->add_cluster_by_parent_accession('GO:0003674');
  
  return $self->non_coding_error unless $object->translation_object;
  my $label = 'GO';
  
  unless ($object->__data->{'links'}) {
    my @similarity_links = @{$object->get_similarity_hash($object->Obj)};
    
    return unless @similarity_links;
    
    $self->_sort_similarity_links(@similarity_links);
  }
  return "<p>No GO terms have been mapped to this entry via UniProt and/or RefSeq.</p>"  unless $object->__data->{'links'}{'go'}; 
  # First process GO terms
  my $html;
  my $go_hash      = $object->get_go_list;
  my $go_slim_hash = $object->get_go_list('goslim_goa');
  if (%$go_hash) {
    $html .= sprintf(
      '<p><strong>Below are the minimal graphs of the GO terms that have been mapped to this entry via UniProt and/or RefSeq. The Maped Terms are highlighted in <span style="color:%s" >%s</span><br/>',
      $ontovis->node_fill_colour, $node_fill_text
    );
    
    if (%$go_slim_hash) {
      $html .= sprintf(
        'Terms from the GOSlim and GOA subset of GO, closest to the matched terms have been highlighted in <span style="color:%s" >%s</span> The nodes are clickable links to GO',
        $ontovis->highlighted_fill_colour, $goslim_goa_fill_text
      )
    }
    
    $html.=  '</strong></p>';
  }
  
  $ontovis->normal_term_accessions(keys %$go_hash);
  $ontovis->highlighted_term_accessions(keys %$go_slim_hash);
  
  $html .= $ontovis->render;  
  
  return $html;
}

1;