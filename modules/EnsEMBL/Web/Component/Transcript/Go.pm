package EnsEMBL::Web::Component::Transcript::Go;

use strict;
use warnings;
use GraphViz;
use EnsEMBL::Web::Tools::OntologyVisualisation;

use Bio::EnsEMBL::DBSQL::OntologyTermAdaptor;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);


sub _init {
  my $self = shift;
  $self->cacheable( 1 );
  $self->ajaxable(  1 );
}

sub caption {
  return undef;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  my $species_defs = $self->object->species_defs;  
  my $ontology_term_adaptor = $object->get_databases('go')->{'go'}->get_GOTermAdaptor();
    
  my $go_sub_dir="/GO/";  
  my $go_dir =$species_defs->ENSEMBL_TMP_DIR_IMG.$go_sub_dir;
  my $go_url = $species_defs->ENSEMBL_BASE_URL.$species_defs->ENSEMBL_TMP_URL_IMG.$go_sub_dir;   
  my $GOIDURL  = "http://amigo.geneontology.org/cgi-bin/amigo/term-details.cgi?term=";  
  my $image_background_colour = $species_defs->colour('goimage','image_background');
  my $node_fill_colour = $species_defs->colour('goimage','node_fill');
  my $node_font_colour = $species_defs->colour('goimage','node_font');
  my $node_border_colour = $species_defs->colour('goimage','node_border');
  my $non_highlight_fill_colour = $species_defs->colour('goimage','non_highlight_fill');
  my $non_highlight_font_colour = $species_defs->colour('goimage','non_highlight_font');
  my $non_highlight_border_colour = $species_defs->colour('goimage','non_highlight_border');    
  my $goslim_goa_fill = $species_defs->colour('goimage','goslim_goa_fill');
  my $goslim_goa_font = $species_defs->colour('goimage','goslim_goa_font');
  my $goslim_goa_border = $species_defs->colour('goimage','goslim_goa_border');

  my $node_fill_text = $species_defs->colour('goimage','node_fill_text');
  $node_fill_text=~s/_/ /g;
  my $goslim_goa_fill_text = $species_defs->colour('goimage','goslim_goa_fill_text');
  $goslim_goa_fill_text=~s/_/ /g;
  
  my $get_relation_type_colour = sub {
    my $relation_type=shift;
    return $species_defs->colour('goimage',$relation_type);
  };  
  my $ontovis = EnsEMBL::Web::Tools::OntologyVisualisation->new($ontology_term_adaptor,$go_dir, $go_url, $GOIDURL, $image_background_colour, $node_fill_colour, $node_font_colour, $node_border_colour, $non_highlight_fill_colour, $non_highlight_font_colour, $non_highlight_border_colour,$goslim_goa_fill, $goslim_goa_font, $goslim_goa_border, $get_relation_type_colour);
$ontovis->add_cluster_by_parent_accession("GO:0005575");
$ontovis->add_cluster_by_parent_accession("GO:0008150");
$ontovis->add_cluster_by_parent_accession("GO:0003674");
  
  return $self->non_coding_error unless $object->translation_object;

  my $label = 'GO';
  unless ($object->__data->{'links'}){
    my @similarity_links = @{$object->get_similarity_hash($object->Obj)};
    return unless (@similarity_links);
    $self->_sort_similarity_links(@similarity_links);
  }

  my $no_data = "<p>No GO terms have been mapped to this entry via UniProt and/or RefSeq.</p>"; 
  return $no_data unless $object->__data->{'links'}{'go'}; 

  # First process GO terms
  my $html;
  my $go_hash  = $object->get_go_list();
  my $go_slim_hash = $object->get_go_list('goslim_goa');

  if (%$go_hash){
    $html.=  "<p><strong>Below are the minimal graphs of the GO terms that have been mapped to this entry via UniProt and/or RefSeq. The Maped Terms are highlighted in <span style=\"color:".$ontovis->node_fill_colour."\" >".$node_fill_text."</span><br/>";
    if (%$go_slim_hash){
      $html .= "Terms from the GOSlim GOA subset of GO, closest to the matched terms have been highlighted in <span style=\"color:".$ontovis->highlighted_fill_colour."\" >".$goslim_goa_fill_text.".</span> The nodes are clickable links to GO";
    }
    $html.=  "</strong></p>";
  }
  $ontovis->normal_term_accessions(keys %$go_hash);
  $ontovis->highlighted_term_accessions(keys %$go_slim_hash);
  $html.=$ontovis->render;  
  return $html;
}

sub table {
  my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px', 'cellpadding' => '2px'} );
  $table->add_columns(
    {'key' => 'go',   'title' => 'GO Accession', 'width' => '5%', 'align' => 'left'},
    {'key' => 'description', 'title' => 'GO Term', 'width' => '55%', 'align' => 'left'},
    {'key' => 'evidence', 'title' => 'Evidence','width' => '3%', 'align' => 'center'},
    {'key' => 'desc', 'title' => 'Annotation Source','width' => '35%', 'align' => 'centre'}
  );
  return $table;
}

sub process_data {
  my ($self, $table, $data_hash) = @_;

  my $object = $self->object;
  my $goview    = $object->database('go') ? 1 : 0;
  my $GOIDURL  = "http://amigo.geneontology.org/cgi-bin/amigo/term-details.cgi?term=";

  foreach my $go (sort keys %{$data_hash}){
    my $row = {};
    my @go_data = @{$data_hash->{$go}||[]};
    my( $evidence, $description, $info_text ) = @go_data;
    my $link_name = $description;
    $link_name =~ s/ /\+/g;

    my $goidurl  = qq(<a href="$GOIDURL$go">$go</a>);
    my $queryurl = qq(<a href="$GOIDURL$go">$description</a>);
    unless( $goview ){
      $goidurl  = $object->get_ExtURL_link($go,'GO',$go);
      $queryurl = $object->get_ExtURL_link($description,'GOTERMNAME', $link_name);
    }
    my $info_text_html;
    my $info_text_url;
    my $info_text_gene;
    my $info_text_species;
    my $info_text_common_name;
                my $info_text_type;
    if($info_text){
    #create URL
     if($info_text=~/from ([a-z]+[ _][a-z]+) (gene|translation) (\w+)/i){
        $info_text_gene= $3;
        $info_text_type= $2;
        $info_text_common_name= ucfirst($1);
      } else{
        #parse error
        warn "regex parse failure in EnsEMBL::Web::Component::Transcript::go()";
      }
      $info_text_species= $object->species;
      (my $species = $info_text_common_name) =~ s/ /_/g;
      my $script = $info_text_type eq 'gene' ? 'geneview?gene=' : 'protview?peptide=';
      $info_text_url= "<a href='/$species/$script$info_text_gene'>$info_text_gene</a>";
      $info_text_html= "[from $info_text_common_name $info_text_url]";
    }
    else{
      $info_text_html= '';
    }

    $row->{'go'} = $goidurl;
    $row->{'description'} = $queryurl;
    $row->{'evidence'} = $evidence;
    $row->{'desc'} = $info_text_html;
    $table->add_row($row);
  }
  return $table;  
}
1;
