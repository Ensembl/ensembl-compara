=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter;

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter;

  my $string_handle = IO::String->new();
  my $w = Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter->new(
    -SOURCE => 'Ensembl', -ALIGNED => 1, -HANDLE => $string_handle
  );

  my $pt = $dba->get_GeneTreeAdaptor()->fetch_by_dbID(3);

  $w->write_trees($pt);
  $w->finish(); #YOU MUST CALL THIS TO WRITE THE FINAL TAG

  my $xml_scalar_ref = $string_handle->string_ref();

  #Or to write to a file via IO::File
  my $file_handle = IO::File->new('output.xml', 'w');
  $w = Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter->new(
    -SOURCE => 'Ensembl', -ALIGNED => 1, -HANDLE => $file_handle
  );
  $w->write_trees($pt);
  $w->finish(); #YOU MUST CALL THIS TO WRITE THE FINAL TAG
  $file_handle->close();

  #Or letting this deal with it
  $w = Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter->new(
    -SOURCE => 'Ensembl', -ALIGNED => 1, -FILE => 'loc.xml'
  );
  $w->write_trees($pt);
  $w->finish(); #YOU MUST CALL THIS TO WRITE THE FINAL TAG
  $w->handle()->close();

=head1 DESCRIPTION

Used as a way of emitting Compara GeneTrees in a format which conforms
to L<PhyloXML|http://www.phyloxml.org/>. The code is built to work with
instances of L<Bio::EnsEMBL::Compara::GeneTree> but can be extended to
operate on any tree structure provided by the Compara Graph infrastructure.

The code provides a number of property extensions to the existing PhyloXML
standard:

=over 8

=item B<Compara:genome_db_name>

Used to show the name of the GenomeDB of the species found. Useful when 
taxonomy is not exact

=item B<Compara:dubious_duplication> 

Indicates locations of potential duplications we are unsure about

=back

The same document is persistent between write_trees() calls so to create
a new XML document create a new instance of this object.

=head1 SUBROUTINES/METHODS

See inline

=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

 Questions may also be sent to the Ensembl help desk at
 <http://www.ensembl.org/Help/Contact>.

=cut

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(check_ref wrap_array);

use base qw/Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter/;

=pod

=head2 new()

  Arg[CDNA]             : Boolean; indicates if we want CDNA emitted or peptide.
                          Defaults to B<false>.
  Arg[ALIGNED]          : Boolean; indicates if we want to emit aligned
                          sequence. Defaults to B<false>.
  Arg[NO_SEQUENCES]     : Boolean; indicates we want to ignore sequence
                          dumping. Defaults to B<false>.

  Description : Creates a new tree writer object.
  Returntype  : Instance of the writer
  Exceptions  : None
  Example     : my $w = Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter->new(
                  -SOURCE => 'Ensembl', -ALIGNED => 1, -HANDLE => $handle
                );
  Status      : Stable

=cut

sub new {
  my ($class, @args) = @_;
  $class = ref($class) || $class;
  my $self = $class->SUPER::new(@args);

  my ($cdna, $aligned, $no_sequences) = 
    rearrange([qw(cdna aligned no_sequences)], @args);

  $cdna ||= 0;
  if( ($cdna || $aligned) && $no_sequences) {
    warning "-CDNA or -ALIGNED was specified but so was -NO_SEQUENCES. Will ignore sequences";
  }

  $self->cdna($cdna);
  $self->aligned($aligned);
  $self->no_sequences($no_sequences);

  return $self;
}

=pod

=head2 cdna()

  Arg[0] : The value to set this to
  Description : Indicates if we want CDNA sequence in the XML. If false
  the code will dump peptide data
  Returntype : Boolean
  Exceptions : None
  Status     : Stable

=cut

sub cdna {
  my ($self, $cdna) = @_;
  $self->{cdna} = $cdna if defined $cdna;
  return $self->{cdna};
}

=pod

=head2 no_sequences()

  Arg[0] : The value to set this to
  Description : Indicates if we do not want to perform sequence dumping 
  Returntype  : Boolean
  Exceptions  : None
  Status      : Stable

=cut

sub no_sequences {
  my ($self, $no_sequences) = @_;
  $self->{no_sequences} = $no_sequences if defined $no_sequences;
  return $self->{no_sequences};
}


=pod

=head2 aligned()

  Arg[0] : The value to set this to
  Description : Indicates if we want to push aligned sequences into the XML
  Returntype : Boolean
  Exceptions : None
  Status     : Stable

=cut

sub aligned {
  my ($self, $aligned) = @_;
  $self->{aligned} = $aligned if defined $aligned;
  return $self->{aligned};
}


sub tree_elements {
  my ($self, $tree) = @_;

  my $w = $self->_writer;

  $w->dataElement('property', $tree->stable_id(),
		  'datatype' => 'xsd:string',
		  'ref' => 'Compara:gene_tree_stable_id',
		  'applies_to' => 'phylogeny');
}

sub dispatch_tag {
  my ($self, $node) = @_;

  if(check_ref($node, 'Bio::EnsEMBL::Compara::GeneTreeMember')) {
    return $self->_member_tag($node);
  }
  elsif(check_ref($node, 'Bio::EnsEMBL::Compara::GeneTreeNode')) {
    return $self->_node_tag($node);
  }

  my $ref = ref($node);
  throw("Cannot process type $ref");
}

sub dispatch_body {
  my ($self, $node) = @_;
  if(check_ref($node, 'Bio::EnsEMBL::Compara::GeneTreeMember')) {
    $self->_member_body($node);
    return;
  }
  elsif(check_ref($node, 'Bio::EnsEMBL::Compara::GeneTreeNode')) {
    $self->_node_body($node);
    return;
  }

  my $ref = ref($node);
  throw("Cannot process type $ref");

  return;
}


###### PROCESSORS

#tags return [ 'tag', {attributes} ]

sub _node_tag {
  my ($self, $node) = @_;
  return ['clade', {branch_length => $node->distance_to_parent()}];
}

#body writes data
sub _node_body {
  my ($self, $node, $defer_taxonomy) = @_;

  my $type  = $node->node_type();
  my $boot  = $node->bootstrap();
  my $stn   = $node->species_tree_node();

  my $w = $self->_writer();

  if($boot) {
    $w->dataElement('confidence', $boot, 'type' => 'bootstrap');
  }

  if(!$defer_taxonomy && $stn) {
    $self->_write_species_tree_node($stn);
  }

  if((defined $type) and ($type eq "duplication" || $type eq "dubious")) {
    $w->startTag('events');
    $w->dataElement('type', 'speciation_or_duplication');
    $w->dataElement('duplications', 1);
    $w->endTag();
    $w->dataElement('confidence', $node->duplication_confidence_score(), 'type' => 'duplication_confidence_score');
  }

  if((defined $type) and ($type eq "dubious")) {
    $w->dataElement('property', 'dubious_duplication',
      'datatype' => 'xsd:int',
      'ref' => 'Compara:dubious_duplication',
      'applies_to' => 'clade'
    );
  }

  return;
}

sub _member_tag {
  my ($self, $node) = @_;
  return $self->_node_tag($node);
}

sub _member_body {
  my ($self, $protein) = @_;

  my $w = $self->_writer();
  $self->_node_body($protein , 1); #Used to defer taxonomy writing

  my $gene = $protein->gene_member();
  my $taxon = $protein->taxon();

  #Stable IDs
  $w->dataElement('name', $gene->stable_id());

  #Taxon
  $self->_write_taxonomy($taxon->taxon_id(), $taxon->name());

  #Dealing with Sequence
  $w->startTag('sequence');
  $w->startTag('accession', 'source' => $self->source());
  $w->characters($protein->stable_id());
  $w->endTag();
  $w->dataElement('name', $protein->display_label()) if $protein->display_label();
  my $location = sprintf('%s:%d-%d',$gene->dnafrag()->name(), $gene->dnafrag_start(), $gene->dnafrag_end());
  $w->dataElement('location', $location);

  if(!$self->no_sequences()) {
    my $mol_seq;
    if($self->aligned()) {
      $mol_seq = ($self->cdna()) ? $protein->alignment_string('cds') : $protein->alignment_string();
    }
    else {
      $mol_seq = ($self->cdna()) ? $protein->other_sequence('cds') : $protein->sequence();
    }

    $w->dataElement('mol_seq', $mol_seq, 'is_aligned' => ($self->aligned() || 0));
  }

  $w->endTag('sequence');

  #Adding GenomeDB
  $w->dataElement('property', $protein->genome_db()->name(),
    'datatype' => 'xsd:string',
    'ref' => 'Compara:genome_db_name',
    'applies_to' => 'clade'
  );

  return;
}

sub tree_type {
  return "gene tree";
}

1;

