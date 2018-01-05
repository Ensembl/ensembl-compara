=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

use Bio::EnsEMBL::Compara::Utils::Preloader;

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
    $self->_node_body($node , 1); #Used to defer taxonomy writing
    $self->_write_seq_member($node);
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

sub _load_all {
    my ($self, $compara_dba, $nodes, $leaves) = @_;

    my $gms = [map {$_->gene_member} @$leaves];
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags($compara_dba->get_DnaFragAdaptor, $leaves, $gms);

    my $taxa = Bio::EnsEMBL::Compara::Utils::Preloader::load_all_NCBITaxon($compara_dba->get_NCBITaxonAdaptor, [map {$_->species_tree_node} @$nodes], $leaves, $gms);
    $compara_dba->get_NCBITaxonAdaptor->_load_tagvalues_multiple( $taxa );

    unless ($self->no_sequences) {
        my $seq_type = ($self->cdna ? 'cds' : undef);
        Bio::EnsEMBL::Compara::Utils::Preloader::load_all_sequences($compara_dba->get_SequenceAdaptor, $seq_type, $leaves);
    }
}

sub _prune_alignment {
  my ($self, $tree) = @_;
  # When the tree is not the entire tree, some columns of the alignment may
  # be full of gaps. Need to remove them
  if (!$self->no_sequences && $self->aligned) {
      my $aln = $tree->get_SimpleAlign(-SEQ_TYPE => ($self->cdna ? 'cds' : undef), -REMOVE_GAPS => 1);
      $self->{_cached_seq_aligns} = {};
      foreach my $seq ($aln->each_seq) {
          $self->{_cached_seq_aligns}->{$seq->display_id} = $seq->seq;
      }
  }
}

sub _write_tree {
    my ($self, $tree) = @_;
    $self->_load_all($tree->adaptor->db, $tree->get_all_nodes, $tree->get_all_Members);
    $self->_prune_alignment($tree) if $tree->{'_pruned'};
    $self->SUPER::_write_tree($tree);
    delete $self->{_cached_seq_aligns};
}

#tags return [ 'tag', {attributes} ]

sub _node_tag {
  my ($self, $node) = @_;
  return ['clade', {branch_length => $node->distance_to_parent()}];
}

#body writes data
sub _node_body {
  my ($self, $node, $defer_taxonomy) = @_;

  my $type  = $node->node_type();
  my $is_dup = ((defined $type) and ($type eq "duplication" || $type eq "dubious")) ? 1 : 0;
  my $boot  = $node->bootstrap();
  my $stn   = $node->species_tree_node();

  my $w = $self->_writer();

  # The elements must be in the same order as in the .xsd !!

  if($boot) {
    $w->dataElement('confidence', $boot, 'type' => 'bootstrap');
  }

  if ($is_dup) {
    $w->dataElement('confidence', $node->duplication_confidence_score(), 'type' => 'duplication_confidence_score');
  }

  if(!$defer_taxonomy && $stn) {
    $self->_write_species_tree_node($stn);
  }

  if ($is_dup) {
    $w->startTag('events');
    $w->dataElement('type', 'speciation_or_duplication');
    $w->dataElement('duplications', 1);
    $w->endTag();
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

sub tree_type {
  return "gene tree";
}

1;

