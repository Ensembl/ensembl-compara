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

  my $label = 'Ontology';

  my $html          =  '<p><h3>The following ontology terms have been annotated to this entry</h3></p>';
  my $columns       = [   
    { key => 'go',              title => 'Accession',      width => '7%',  align => 'left'   },
    { key => 'description',     title => 'Term',           width => '30%', align => 'left'   },
    { key => 'evidence',        title => 'Evidence',          width => '3%',  align => 'center' },
    { key => 'desc',            title => 'Annotation Source', width => '18%', align => 'center' },
    { key => 'goslim_goa_acc',  title => 'GOSlim Accessions', width => '9%', align => 'centre' },
    { key => 'goslim_goa_title',title => 'GOSlim Terms', width => '30%', align => 'centre' },
  ];

# This view very much depends on existance of the ontology db 
# But it does not have to be - you can still display the ontology terms with the links to the corresponding 
# ontology website.
   
  my %clusters = $self->hub->species_defs->multiX('ONTOLOGIES');
  my $terms_found = 0;
  foreach my $oid (sort {$a <=> $b} keys %clusters) {
    my $go_hash  = $object->get_go_list($clusters{$oid}->{db}, $clusters{$oid}->{root});

    if (%$go_hash) {
	$terms_found = 1;
        my $description = sprintf("%s: %s",$clusters{$oid}->{db},$clusters{$oid}->{description});
	$html .= "<p><h4>Descendants of $description:</h4>";
      #add goslim_generic
      my $go_database=$self->hub->get_databases('go')->{'go'};    
      foreach (keys %$go_hash){
        my $query = qq(        
          SELECT t.accession, t.name,c.distance
          FROM closure c join term t on c.parent_term_id= t.term_id
          where child_term_id = (SELECT term_id FROM term where accession='$_')
          and parent_term_id in (SELECT term_id FROM term t where subsets like '%goslim_generic%')
          order by distance         
        );
        my $result = $go_database->dbc->db_handle->selectall_arrayref($query);
	foreach my $r (@$result) {
	    my ($accession, $name, $distance) =@{$r};
	    $go_hash->{$_}->{goslim}->{$accession}->{'name'} = $name;
	    $go_hash->{$_}->{goslim}->{$accession}->{'distance'} = $distance;
        }
      }
      my $table = $self->new_table($columns, [], { margin => '1em 0px', cellpadding => '2px' });
      $self->process_data($table, $go_hash, $clusters{$oid}->{db});
      $html .= $table->render;
    }
  }

  return '<p>No ontology terms have been annotated to this entity.</p>' unless $terms_found; 

  return "</p>$html";
}

sub process_data {
  my ($self, $table, $data_hash, $extdb) = @_;
  my $hub     = $self->hub;
  my $object  = $self->object;
  my $species = $hub->species;
  my $species_path = $hub->species_defs->species_path($species);

  foreach my $go (sort keys %$data_hash) {
    my $row     = {};
    my $ghash = $data_hash->{$go} || {};

    my $go_link    = $hub->get_ExtURL_link($go, $extdb, $go);
    
    
    my $info_text_html;
    my $info_text_url;
    my $info_text_gene;
    my $info_text_species;
    my $info_text_common_name;
    my $info_text_type;
    
    if (my $info_text = $ghash->{'info'}) {
     # create URL
     if ($info_text =~ /from ([a-z]+[ _][a-z]+) (gene|translation) (\S+)/i) {
        $info_text_gene        = $3;
        $info_text_type        = $2;
        $info_text_common_name = ucfirst $1;
      } else {
        warn "regex parse failure in EnsEMBL::Web::Component::Transcript::go()"; # parse error
      }
      
      $info_text_species = $species;
      (my $species       = $info_text_common_name) =~ s/ /_/g;
      my $type   = $info_text_type eq 'gene' ? 'Gene' : 'Transcript';
      my $action = $info_text_type eq 'translation'  ? 'ProteinSummary' : 'Summary';
      my $param_type = $info_text_type eq 'translation' ? 'p' : substr($info_text_type, 0, 1);        
  
      my $info_text_url = $hub->url({
        species     => $species,
        type        => $type,
        action      => $action,
        $param_type => $info_text_gene,
        __clear     => 1,
      });
      $info_text_html    = "[from $info_text_common_name <a href='$info_text_url'>$info_text_gene</a>]";
    } else {
      $info_text_html = '';
    }

    my $goslim_goa_acc='';
    my $goslim_goa_desc='';

    my $goslim_goa_hash = $ghash->{goslim} || {};
    foreach (keys %$goslim_goa_hash){
      $goslim_goa_acc.=$hub->get_ExtURL_link($_, 'GOSLIM_GOA', $_)."<br/>";
      $goslim_goa_desc.=$goslim_goa_hash->{$_}->{'name'}."<br/>";
    }

    $row->{'go'}          = $go_link;
    $row->{'description'} = $ghash->{'term'};
    $row->{'evidence'}    = $ghash->{'evidence'};
    $row->{'desc'}        = join ', ', grep {$_} ($info_text_html, $ghash->{source});
    $row->{'goslim_goa_acc'}   = $goslim_goa_acc;
    $row->{'goslim_goa_title'} = $goslim_goa_desc;
    
    $table->add_row($row);
  }
  
  return $table;  
}

1;
