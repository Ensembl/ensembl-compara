package EnsEMBL::Web::Component::Transcript::Go;

use strict;
use warnings;
use URI::Escape;
use GraphViz;

use Bio::EnsEMBL::DBSQL::OntologyTermAdaptor;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Transcript);

my $existing_terms;
my $existing_edges;

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
  if (%$go_hash){
    $html =  "<p><strong>The following GO terms have been mapped to this entry via UniProt and/or RefSeq:</strong></p>";
    my $table = $self->table;
    $self->process_data($table, $go_hash);
    $html .= $table->render;
  }
  # then add  GOSlim info
  my $go_slim_hash = $object->get_go_list('goslim_goa');
  if (%$go_slim_hash){
    $html .= "<p><strong>The following GO terms are the closest ones in the GOSlim GOA subset
    for the above terms:</strong> (click to enlarge)</p>";  
    my $species_defs = $self->object->species_defs;
    my $go_sub_dir="/GO/";
    my $go_dir =$species_defs->ENSEMBL_TMP_DIR_IMG.$go_sub_dir;
    my $go_url = $species_defs->ENSEMBL_BASE_URL.$species_defs->ENSEMBL_TMP_URL_IMG.$go_sub_dir; 
    my $go_image;
    my $image_background = $species_defs->colour('goimage','image_background') || 'transparent';
    $image_background='#'.$image_background if ($image_background ne 'transparent');

    my $node_fill = $species_defs->colour('goimage','node_fill') || 'transparent';
    $node_fill='#'.$node_fill if ($node_fill ne 'transparent');
    my $node_font = $species_defs->colour('goimage','node_font') || '000000' ;
    $node_font='#'.$node_font if ($node_font ne 'transparent');
    my $node_border = $species_defs->colour('goimage','node_border') || '000000';
    $node_border='#'.$node_border if ($node_border ne 'transparent');

    my $ontology_term_adaptor = $object->get_databases('go')->{'go'}->get_GOTermAdaptor();
    my $graph = GraphViz->new(bgcolor=>$image_background, style=>'filled', node => {shape => 'box', fontsize => '16pt', fontname=>'Times-Roman', fontname=>'Helvetica', fontnames=>'ps'});
    my $GOIDURL  = "http://amigo.geneontology.org/cgi-bin/amigo/term-details.cgi?term=";
    for my $key ( sort(keys %$go_slim_hash )) {#add the nodes we retreived, and highlight them
      $go_image.=$key;
     
      #get term from go
      my $term = $ontology_term_adaptor->fetch_by_accession($key);
      #add the node if needed
      if(! $existing_terms->{$key}){
        $existing_terms->{$key}=1;
        $graph->add_node($self->format_node_name($term),title=>'bla', URL=>$GOIDURL.$term->accession, style=>'filled', color=>$node_border,fillcolor=>$node_fill, fontcolor=>$node_font);
      }
    }
    for my $key ( sort(keys %$go_slim_hash )) {#add all parents of the nodes we retreived
      my $term = $ontology_term_adaptor->fetch_by_accession($key);
    $self->add_parents($term,$graph,$ontology_term_adaptor,$GOIDURL);
    }      
    $go_image.=".png";
    mkdir($go_dir);
    # warn $graph->as_cmapx;
    open (MYFILE, '>>'.$go_dir.$go_image);
    print MYFILE $graph->as_png;
    close (MYFILE);
    my $image_map = $graph->as_cmapx;
    $image_map =~ s/\\n/ /g;
    $html.=$image_map;
    $html.=qq(<img usemap="#test" src=").$go_url.$go_image.qq(" border="0">);
  }
  return $html;
}

sub add_parents{
  my $self=shift;
  my $term = shift;
  my $graph=shift;
  my $ontology_term_adaptor = shift;
  my $parents = $ontology_term_adaptor->fetch_all_by_child_term($term);
  my $GOIDURL = shift;
  my $species_defs = $self->object->species_defs;
  my $non_highlight_fill = $species_defs->colour('goimage','non_highlight_fill') || 'transparent';
  $non_highlight_fill='#'.$non_highlight_fill if ($non_highlight_fill ne 'transparent');
  my $non_highlight_font = $species_defs->colour('goimage','non_highlight_font') || '000000';
  $non_highlight_font='#'.$non_highlight_font if ($non_highlight_font ne 'transparent');    
  my $non_highlight_border = $species_defs->colour('goimage','non_highlight_border') || '000000';
  $non_highlight_border='#'.$non_highlight_border if ($non_highlight_border ne 'transparent');    

  my $ancestors = $ontology_term_adaptor->_fetch_ancestor_chart($term);      
  foreach (keys %$ancestors)  {
    my $ancestor_terms=$ancestors->{$_};
    foreach my $relation (keys %$ancestor_terms ){
      if(ref $ancestor_terms->{$relation} eq "ARRAY" ){#all parents are in 'name' =>[term,term] form
        foreach my $trm (@{$ancestor_terms->{$relation}}){
          foreach (@$parents){
            if($trm->accession eq $_->accession){#check that the parent is a direct parent
              if(! $existing_terms->{$trm->accession}){
                $existing_terms->{$trm->accession}=1;
                $graph->add_node($self->format_node_name($trm), URL=>$GOIDURL.$trm->accession, style=>'filled', color=>$non_highlight_border,fillcolor=>$non_highlight_fill, fontcolor=>$non_highlight_font);
              }
              if(! $existing_edges->{$term->accession.$trm->accession.$relation}){
                $existing_edges->{$term->accession.$trm->accession.$relation}=1;
                my $edge_colour = "#".($species_defs->colour('goimage',$relation)|| '000000' );
                $graph->add_edge($self->format_node_name($term) => $self->format_node_name($trm), label=>$relation, color=>$edge_colour, fontcolor=>$edge_colour, tooltip=>'nnnn');
              }
              $self->add_parents($trm,$graph,$ontology_term_adaptor,$GOIDURL);            
            }
          }
        }
      }
    }
  }
}

sub format_node_name{
  my $self=shift;
  my $trm = shift;
  my $len = (length ($trm->name) > length ($trm->accession) )?  length($trm->name) - length($trm->accession) :0;
  my $return_string = $trm->accession;
  $return_string.="\n".$trm->name;
  return $return_string;
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
