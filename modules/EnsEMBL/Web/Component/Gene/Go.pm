=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Gene::Go;

# GO:0005575          cellular_component
# GO:0008150          biological_process
# GO:0003674          molecular_function

use strict;

use EnsEMBL::Web::Utils::FormatText qw(helptip);

use base qw(EnsEMBL::Web::Component::Gene);

sub _init {
  my $self = shift;
  $self->cacheable(1);
  $self->ajaxable(1);
}

sub content {
  my $self   = shift;
  my $object = $self->object;  
  
 # return $self->non_coding_error unless $object->translation_object;
  
  # This view very much depends on existance of the ontology db,
  # but it does not have to - you can still display the ontology terms with the links to the corresponding 
  # ontology website.
  
  my $hub         = $self->hub;
  my $function    = $hub->function;  
  my $adaptor     = $hub->get_adaptor('get_OntologyTermAdaptor', 'go');
  my %clusters    = $hub->species_defs->multiX('ONTOLOGIES');
  my $terms_found = 0;
  my $label       = 'Ontology';
  my $columns     = [   
    { key => 'go',              title => 'Accession',         sort => 'html', width => '10%', align => 'left'   },
    { key => 'term',            title => 'Term',              sort => 'text', width => '20%', align => 'left'   },
    { key => 'evidence',        title => 'Evidence',          sort => 'text', width => '3%',  align => 'left'   },
    { key => 'source',          title => 'Annotation source', sort => 'html', width => '15%', align => 'left'   },    
    { key => 'mapped',          title => 'Mapped using',      sort => 'html', width => '15%', align => 'left', 'hidden' => 1 },    
    { key => 'transcript_id',   title => 'Transcript IDs',    sort => 'text', width => '10%', align => 'left' },
    { key => 'extra_link',      title => '',                  sort => 'none', width => '10%', align => 'left' },
  ];
    
  my $html    = '<ul>';
  my $tables  = '';
  my $i       = 0;
  my $oid     = (grep { $clusters{$_}{'description'} eq $function } keys %clusters)[0];
  my $go_hash = $object->get_go_list($clusters{$oid}{'db'}, $clusters{$oid}{'root'});
  
  if (%$go_hash) {
    my $table = $self->new_table($columns, [], { data_table => 1 });
    (my $desc = ucfirst $clusters{$oid}{'description'}) =~ s/_/ /g;
   
    $self->process_data($table, $go_hash, $clusters{$oid}{'db'});    

    $tables     .= $table->render;
    $terms_found = 1;
    $i++;
  }

  $html .= '</ul>'.$tables;

  return $terms_found ? $html : '<p>No ontology terms have been annotated to this entity.</p>';
}

sub biomart_link {
  my ($self, $go) = @_;
  
  my (@species)   = split /_/, $self->object->species;
  my $attr_prefix = lc(substr($species[0], 0, 1) . $species[scalar(@species)-1] . "_gene_ensembl"); 
  my $link        = "//".$SiteDefs::ENSEMBL_SERVERNAME."/biomart/martview?VIRTUALSCHEMANAME=default&ATTRIBUTES=$attr_prefix.default.feature_page.ensembl_gene_id|$attr_prefix.default.feature_page.ensembl_transcript_id|$attr_prefix.default.feature_page.external_gene_name|$attr_prefix.default.feature_page.description|$attr_prefix.default.feature_page.chromosome_name|$attr_prefix.default.feature_page.start_position|$attr_prefix.default.feature_page.end_position&FILTERS=$attr_prefix.default.filters.go_parent_term.$go"; 
  my $url         = $self->hub->species_defs->ENSEMBL_MART_ENABLED ? qq{<a href="$link">Search BioMart</a>} : ""; 
  
  return $url;
}

sub process_data {
  my ($self, $table, $data, $extdb) = @_;
  
  my $hub              = $self->hub;
  # this is a dirty way of having all the go term description until core decide to have a table for them, this is how we will have to do thing
  my $description_hash = {
                          'EXP' => 'Inferred from Experiment', 
                          'HDA' => 'High-throughput Direct Assay',
                          'IBA' => 'Inferred from Biological aspect of Ancestor',
                          'IC'  => 'Inferred by Curator', 
                          'IDA' => 'Inferred from Direct Assay', 
                          'IEA' => 'Inferred from Electronic Annotation', 
                          'IEP' => 'Inferred from Expression Pattern', 
                          'IGC' => 'Inferred from Genomic Context', 
                          'IGI' => 'Inferred from Genetic Interaction', 
                          'IMP' => 'Inferred from Mutant Phenotype', 
                          'IPI' => 'Inferred from Physical Interaction', 
                          'ISA' => 'Inferred from Sequence Alignment', 
                          'ISM' => 'Inferred from Sequence Model', 
                          'ISO' => 'Inferred from Sequence Orthology', 
                          'ISS' => 'Inferred from Sequence or Structural Similarity', 
                          'NAS' => 'Non-traceable Author Statement', 
                          'ND'  => 'No biological Data available', 
                          'NR'  => 'Not Recorded', 
                          'RCA' => 'Inferred from Reviewed Computational Analysis', 
                          'TAS' => 'Traceable Author Statement', 
                        };
  
  foreach my $go (sort keys %$data) {
    my $hash        = $data->{$go} || {};
    my $go_link     = $hub->get_ExtURL_link($go, $extdb, $go);
    my $mart_link   = $self->biomart_link($go) ? "<li>".$self->biomart_link($go)."</li>": "";
    my $loc_link    = '<li><a rel="notexternal" href="' . $hub->url({type  => 'Location', action => 'Genome', ftype => 'Gene', id  => $go, gotype => $extdb}) . ( scalar @{$self->hub->species_defs->ENSEMBL_CHROMOSOMES} ? '">View on karyotype</a></li>' : '">View associated genes</a></li>' );

    my $goslim      = $hash->{'goslim'} || {};
    my $row         = {};
    my $go_evidence = [ split /\s*,\s*/, $hash->{'evidence'} || '' ];
   (my $trans       = $hash->{transcript_id}) =~ s/^,/ /; # GO terms with multiple transcripts
    my %all_trans   = map{$_ => $hub->url({type => 'Transcript', action => 'Summary',t => $_,})} split(/,/,$trans) if($hash->{transcript_id} =~ /,/);
    
    my $mapped;

    if($hash->{'term'}) {
      $row->{'go'}               = $go_link;
      $row->{'term'}             = $hash->{'term'};
      $row->{'evidence'}         = join ', ', map helptip($_, $description_hash->{$_} // 'No description available'), @$go_evidence;
      $row->{'mapped'}           = $hash->{'mapped'} || '';
      $row->{'source'}           = $hash->{'source'} || '';
      $row->{'transcript_id'}    = %all_trans ? join("<br>", map { qq{<a href="$all_trans{$_}">$_</a>} } keys %all_trans) : '<a href="'.$hub->url({type => 'Transcript', action => 'Summary',t => $hash->{transcript_id},}).'">'.$hash->{transcript_id}.'</a>';
      $row->{'extra_link'}       = $mart_link || $loc_link ? qq{<ul class="compact">$mart_link$loc_link</ul>} : "";
      
      $table->add_row($row);
    }
  }
  
  return $table;  
}

1;
