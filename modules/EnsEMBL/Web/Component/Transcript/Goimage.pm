# $Id$

package EnsEMBL::Web::Component::Transcript::Goimage;

use strict;

use EnsEMBL::Web::Tools::OntologyVisualisation;
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
  my $ontology_term_adaptor       = $hub->get_databases('go')->{'go'}->get_GOTermAdaptor;
  my $go_sub_dir                  = '/GO/';  
  my $go_dir                      = $species_defs->ENSEMBL_TMP_DIR_IMG . $go_sub_dir;
  my $go_url                      =  $species_defs->ENSEMBL_TMP_URL_IMG . $go_sub_dir;
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
  
  my %clusters = $species_defs->multiX('ONTOLOGIES');
  return "<p>Ontology database not found.</p>" unless %clusters;

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

  my @goslim_subset = ("goslim_goa");
  if (%$go_hash) {
    $html .= sprintf(
      '<p><strong>The chart shows the ancestry of the ontology terms that have been mapped to this entity. <br/>
The nodes are clickable links to the ontology websites. </strong>
<br/><strong>Terms:</strong> <span style="width:20px"> &nbsp; </span> <span style="color:#ffffff;background:%s"> Mapped terms </span> &nbsp;<span style="width:20px">&nbsp;</span>',
      $ontovis->node_fill_colour
    );
    
    #if (%$go_slim_hash) {
    if (@goslim_subset){
      $html .= sprintf(
        ' &nbsp;<span style="border:2px solid orange"> GOSlim GOA terms </span>',
        $ontovis->highlighted_fill_colour
      )
    }
    
    $html.=  '<br/></p><br/>';
    $terms_found = 1;
  }

  return "<p>No ontology terms have been mapped to this entry.</p>"  unless $terms_found;   

  $ontovis->normal_term_accessions(keys %$go_hash);
  $ontovis->highlighted_subsets(@goslim_subset);
  
  $html .= $ontovis->render;  
  return $html;
}

1;
