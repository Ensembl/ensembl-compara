# GO:0005575  	cellular_component
# GO:0008150  	biological_process
# GO:0003674  	molecular_function

package EnsEMBL::Web::Component::Transcript::Go;

use strict;
use warnings;
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
  my @clusters = ('GO:0005575', 'GO:0008150', 'GO:0003674');
  my @cluster_descr = ('cellular_component', 'biological_process', 'molecular_function');
  $html =  "<p><h3>The following GO terms have been mapped to this entry via UniProt and/or RefSeq:</h3></p>";  
  for(my $i=0; $i< scalar(@clusters); $i++){
    $html .=  '<h4>The following terms are descendants of '.$cluster_descr[$i].'</h4>';
    my $go_hash  = $object->get_go_list('GO', $clusters[$i]);
    if (%$go_hash){
      my $table = $self->table;
      $self->process_data($table, $go_hash);
      $html .= $table->render;
    }
    # then add  GOSlim info
    my $go_slim_hash = $object->get_go_list('goslim_goa', $clusters[$i]);
    if (%$go_slim_hash){
      $html .= "<p><strong>The following GO terms are the closest ones in the GOSlim GOA subset
        for the above terms:</strong></p>";
      my $go_slim_table = $self->table;
      $self->process_data($go_slim_table, $go_slim_hash);
      $html .= $go_slim_table->render;
    }
  }

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
