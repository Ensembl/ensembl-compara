# $Id$

package EnsEMBL::Web::Component::Transcript::Go;

# GO:0005575          cellular_component
# GO:0008150          biological_process
# GO:0003674          molecular_function

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
  
  # This view very much depends on existance of the ontology db,
  # but it does not have to - you can still display the ontology terms with the links to the corresponding 
  # ontology website.
  
  my $hub         = $self->hub;
  my $adaptor     = $hub->get_databases('go')->{'go'}->get_OntologyTermAdaptor;
  my %clusters    = $hub->species_defs->multiX('ONTOLOGIES');
  my $terms_found = 0;
  my $label       = 'Ontology';
  my $columns     = [   
    { key => 'go',               title => 'Accession',         sort => 'html', width => '7%',  align => 'left'   },
    { key => 'description',      title => 'Term',              sort => 'text', width => '30%', align => 'left'   },
    { key => 'evidence',         title => 'Evidence',          sort => 'text', width => '3%',  align => 'center' },
    { key => 'desc',             title => 'Annotation Source', sort => 'html', width => '18%', align => 'center' },
    { key => 'goslim_goa_acc',   title => 'GOSlim Accessions', sort => 'html', width => '9%',  align => 'centre' },
    { key => 'goslim_goa_title', title => 'GOSlim Terms',      sort => 'text', width => '30%', align => 'centre' },
  ];
  


  my $html    = '<ul>';
  my $tables  = '';
  my $i = 0;
  
  foreach my $oid (sort { $a <=> $b } keys %clusters) {
    my $go_hash = $object->get_go_list($clusters{$oid}{'db'}, $clusters{$oid}{'root'});
    
    if (%$go_hash) {
      my $table = $self->new_table($columns, [], { data_table => 1 });
      (my $desc = ucfirst $clusters{$oid}{'description'}) =~ s/_/ /g;
      
      # add goslim_generic
      foreach my $key (keys %$go_hash) {
        $go_hash->{$key}{'goslim'}{$_->accession}{'name'} = $_->name for @{$adaptor->fetch_all_by_descendant_term($adaptor->fetch_by_accession($key), '%goslim_generic%')};;
      }
      
      $self->process_data($table, $go_hash, $clusters{$oid}{'db'});
      
      $html       .= qq(<li><a href="#ont_$i">$clusters{$oid}{'db'}: $desc</a></li>);
      $tables     .= qq(<h2 id="ont_$i">Descendants of $clusters{$oid}{'db'}: $desc</h2>) . $table->render;
      $terms_found = 1;
      $i++;
    }
  }
  $html .= '</ul>'.$tables;

  return $terms_found ? $html : '<p>No ontology terms have been annotated to this entity.</p>';
}

sub process_data {
  my ($self, $table, $data, $extdb) = @_;
  my $hub = $self->hub;
  
  foreach my $go (sort keys %$data) {
    my $hash    = $data->{$go} || {};
    my $go_link = $hub->get_ExtURL_link($go, $extdb, $go);
    my $goslim  = $hash->{'goslim'} || {};
    my $row     = {};
    my ($goslim_goa_acc, $goslim_goa_title, $desc);
    
    if ($hash->{'info'}) {
      my ($gene, $type, $common_name);
      
      # create URL
      if ($hash->{'info'} =~ /from ([a-z]+[ _][a-z]+) (gene|translation) (\S+)/i) {
        $gene        = $3;
        $type        = $2;
        $common_name = ucfirst $1;
      } else {
        warn 'regex parse failure in EnsEMBL::Web::Component::Transcript::go()'; # parse error
      }
      
      (my $species   = $common_name) =~ s/ /_/g;
      my $param_type = $type eq 'translation' ? 'p' : substr $type, 0, 1;
      my $url        = $hub->url({
        species     => $species,
        type        => $type eq 'gene'        ? 'Gene'           : 'Transcript',
        action      => $type eq 'translation' ? 'ProteinSummary' : 'Summary',
        $param_type => $gene,
        __clear     => 1,
      });
      
      $desc = qq{[from $common_name <a href="$url">$gene</a>]};
    }
    
    foreach (keys %$goslim) {
      $goslim_goa_acc   .= $hub->get_ExtURL_link($_, 'GOSLIM_GOA', $_) . '<br />';
      $goslim_goa_title .= $goslim->{$_}{'name'} . '<br />';
    }
    
    $row->{'go'}               = $go_link;
    $row->{'description'}      = $hash->{'term'};
    $row->{'evidence'}         = $hash->{'evidence'};
    $row->{'desc'}             = join ', ', grep $_, ($desc, $hash->{'source'});
    $row->{'goslim_goa_acc'}   = $goslim_goa_acc;
    $row->{'goslim_goa_title'} = $goslim_goa_title;
    
    $table->add_row($row);
  }
  
  return $table;  
}

1;
