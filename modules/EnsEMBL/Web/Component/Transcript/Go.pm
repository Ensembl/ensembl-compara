# $Id$

package EnsEMBL::Web::Component::Transcript::Go;

# GO:0005575  	cellular_component
# GO:0008150  	biological_process
# GO:0003674  	molecular_function

use strict;

use base qw(EnsEMBL::Web::Component::Transcript);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;  
  
  return $self->non_coding_error unless $object->translation_object;

  my $label = 'GO';
  
  unless ($object->__data->{'links'}) {
    my @similarity_links = @{$object->get_similarity_hash($object->Obj)};
    
    return unless @similarity_links;
    
    $self->_sort_similarity_links(@similarity_links);
  }

  return '<p>No GO terms have been mapped to this entry via UniProt and/or RefSeq.</p>' unless $object->__data->{'links'}{'go'}; 

  # First process GO terms
  my @clusters      = ( 'GO:0005575', 'GO:0008150', 'GO:0003674' );
  my @cluster_descr = ( 'cellular_component', 'biological_process', 'molecular_function ');
  my $html          =  '<p><h3>The following GO terms have been mapped to this entry via UniProt and/or RefSeq:</h3></p>';
  my $columns       = [   
    { key => 'go',              title => 'GO Accession',      width => '5%',  align => 'left'   },
    { key => 'description',     title => 'GO Term',           width => '30%', align => 'left'   },
    { key => 'evidence',        title => 'Evidence',          width => '3%',  align => 'center' },
    { key => 'desc',            title => 'Annotation Source', width => '24%', align => 'centre' },
    { key => 'goslim_goa_acc',  title => 'GOSlim GOA Accessions', width => '5%', align => 'centre' },
    { key => 'goslim_goa_title',title => 'GOSlim GOA Terms', width => '30%', align => 'centre' }
  ];
  
  
  for (my $i = 0; $i <  scalar @clusters; $i++) {
    $html .= "<p><h3>The following terms are descendants of $cluster_descr[$i]</h3>";
    
    my $go_hash  = $object->get_go_list('GO', $clusters[$i]);
    
    if (%$go_hash) {
      #add closest goslim_goa
      my $go_database=$self->hub->get_databases('go')->{'go'};    
      foreach (keys %$go_hash){
        # my $query = qq(        
          # SELECT t.accession, t.name,c.distance
          # FROM closure c join term t on c.parent_term_id= t.term_id
          # where child_term_id = (SELECT term_id FROM term where accession='$_')
          # and parent_term_id in (SELECT term_id FROM term t where subsets like '%goslim_goa%')
          # order by distance         
        # );
        my $query = qq(        
          SELECT t.accession, t.name
          FROM closure c join term t on c.parent_term_id= t.term_id
          where child_term_id = (SELECT term_id FROM term where accession='$_')
          and parent_term_id in (SELECT term_id FROM term t where subsets like '%goslim_goa%')
        );
        my $result = $go_database->dbc->db_handle->selectall_arrayref($query);
        for (my $i=0; ($i< scalar(@$result)) ; $i++){
          my $accession=@{@$result[$i]}[0];
          my $name=@{@$result[$i]}[1];
          $go_hash->{$_}[3]->{$accession}->{'name'} = $name;
          # $go_hash->{$_}[3]->{$accession}->{'distance'} = $distance;
        }
      }
      
      my $table = $self->new_table($columns, [], { margin => '1em 0px', cellpadding => '2px' });
      $self->process_data($table, $go_hash);
      $html .= $table->render;
    }
  }
  return "</p>$html";
}

sub process_data {
  my ($self, $table, $data_hash) = @_;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $species = $hub->species;

  foreach my $go (sort keys %$data_hash) {
    my $row     = {};
    my @go_data = @{$data_hash->{$go} || []};
    my ($evidence, $description, $info_text,$goslim_goa_hash) = @go_data;


    my $go_link    = $hub->get_ExtURL_link($go, 'GO', $go);
    my $query_link = $hub->get_ExtURL_link($description, 'GO', $go);
    
    my $info_text_html;
    my $info_text_url;
    my $info_text_gene;
    my $info_text_species;
    my $info_text_common_name;
    my $info_text_type;
    
    if ($info_text) {
     # create URL
     if ($info_text =~ /from ([a-z]+[ _][a-z]+) (gene|translation) (\w+)/i) {
        $info_text_gene        = $3;
        $info_text_type        = $2;
        $info_text_common_name = ucfirst $1;
      } else {
        warn "regex parse failure in EnsEMBL::Web::Component::Transcript::go()"; # parse error
      }
      
      $info_text_species = $species;
      (my $species       = $info_text_common_name) =~ s/ /_/g;
      my $script         = $info_text_type eq 'gene' ? 'geneview?gene=' : 'protview?peptide=';
      $info_text_url     = "<a href='/$species/$script$info_text_gene'>$info_text_gene</a>";
      $info_text_html    = "[from $info_text_common_name $info_text_url]";
    } else {
      $info_text_html = '';
    }

    my $goslim_goa_acc='';
    my $goslim_goa_desc='';
    # my $distance;
    foreach (keys %$goslim_goa_hash){
      # $distance = $goslim_goa_hash->{$_}->{'distance'};   
      $goslim_goa_acc.=$hub->get_ExtURL_link($_, 'GOSLIM_GOA', $_)."<br/>";
      $goslim_goa_desc.=$hub->get_ExtURL_link($goslim_goa_hash->{$_}->{'name'}, 'GOSLIM_GOA', $_)."<br/>";
    }
    $row->{'go'}          = $go_link;
    $row->{'description'} = $query_link;
    $row->{'evidence'}    = $evidence;
    $row->{'desc'}        = $info_text_html;
    $row->{'goslim_goa_acc'}   = $goslim_goa_acc;
    $row->{'goslim_goa_title'} = $goslim_goa_desc;
    # $row->{'distance'} = $distance;    
    
    
    $table->add_row($row);
  }
  
  return $table;  
}

1;
