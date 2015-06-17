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
  
  my $hub              = $self->hub;
  # this is a dirty way of having all the go term description until core decide to have a table for them, this is how we will have to do thing
  my $description_hash = {'EXP' => 'Inferred from Experiment', 'IC' => 'Inferred by Curator', 'IDA' => 'Inferred from Direct Assay', 'IEA' => 'Inferred from Electronic Annotation', 'IEP' => 'Inferred from Expression Pattern', 'IGC' => 'Inferred from Genomic Context', 'IGI' => 'Inferred from Genetic Interaction', 'IMP' => 'Inferred from Mutant Phenotype', 'IPI' => 'Inferred from Physical Interaction', 'ISA' => 'Inferred from Sequence Alignment', 'ISM' => 'Inferred from Sequence Model', 'ISO' => 'Inferred from Sequence Orthology', 'ISS' => 'Inferred from Sequence or Structural Similarity', 'NAS' => 'Non-traceable Author Statement', 'ND' => 'No biological Data available', 'RCA' => 'Inferred from Reviewed Computational Analysis', 'TAS' => 'Traceable Author Statement', 'NR' => 'Not Recorded', 'IBA' => 'Inferred from Biological aspect of Ancestor'};
  
  foreach my $go (sort keys %$data) {
    my $hash        = $data->{$go} || {};
    my $go_link     = $hub->get_ExtURL_link($go, $extdb, $go);
    my $goslim      = $hash->{'goslim'} || {};
    my $row         = {};
    my $go_evidence = $hash->{'evidence'}; 
    
    my ($goslim_goa_acc, $goslim_goa_title, $desc);
    
    $description_hash->{$go_evidence} = $description_hash->{$go_evidence} ? $description_hash->{$go_evidence} : 'No description available';
    
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
        action      => $type eq 'translation' ? 'Ontology' : 'Summary',
        $param_type => $gene,
        __clear     => 1,
      });
      
      $desc = qq{Propagated from $common_name <a href="$url">$gene</a> by orthology};
    }
    
    foreach (keys %$goslim) {
      $goslim_goa_acc   .= $hub->get_ExtURL_link($_, 'GOSLIM_GOA', $_) . '<br />';
      $goslim_goa_title .= $goslim->{$_}{'name'} . '<br />';
    }
    
    $row->{'go'}               = $go_link;
    $row->{'description'}      = $hash->{'term'};
    $row->{'evidence'}         = $self->helptip($go_evidence, $description_hash->{$go_evidence});
    $row->{'desc'}             = join ', ', grep $_, ($desc, $hash->{'source'});
    $row->{'goslim_goa_acc'}   = $goslim_goa_acc;
    $row->{'goslim_goa_title'} = $goslim_goa_title;
    
    $table->add_row($row);
  }
  
  return $table;  
}

1;
