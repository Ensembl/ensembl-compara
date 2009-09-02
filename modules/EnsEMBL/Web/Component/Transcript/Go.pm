package EnsEMBL::Web::Component::Transcript::Go;

use strict;
use warnings;
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
  my $databases = $object->DBConnection;
  my $goview    = $object->database('go') ? 1 : 0;

  my $go_hash  = $object->get_go_list();
  my $GOIDURL  = "http://amigo.geneontology.org/cgi-bin/amigo/term-details.cgi?term=";
  #my $QUERYURL = "http://amigo.geneontology.org/cgi-bin/amigo/search.cgi?query=";
  my $URLS     = $object->ExtURL;

 return unless ($go_hash);
  my $html =  "<p><strong>The following GO terms have been mapped to this entry via UniProt and/or RefSeq:</strong></p>";

  #$html .= qq(<dl>);
   my $table = new EnsEMBL::Web::Document::SpreadSheet( [], [], {'margin' => '1em 0px'} );
    $table->add_columns(
      {'key' => 'go',   'title' => 'GO Accession', 'width' => '5%', 'align' => 'left'},
      {'key' => 'evidence', 'title' => 'Evidence','width' => '3%', 'align' => 'centre'},
      {'key' => 'description', 'title' => 'Go Term', 'width' => '55%', 'align' => 'left'},
      {'key' => 'desc', 'title' => 'Annotation Source','width' => '35%', 'align' => 'centre'}
    );

  foreach my $go (sort keys %{$go_hash}){
    my $row = {};
    my @go_data = @{$go_hash->{$go}||[]};
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
  #$html .= qq(<dd>$goidurl $info_text_html [$queryurl] <code>$evidence</code></dd>\n);
  }
  #$html .= qq(</dl>);
  $html .= $table->render;
 return $html;
}

1;
