package Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter;

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter;
  
  my $string_handle = IO::String->new();
  my $w = Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter->new(
    -SOURCE => 'Ensembl', -ALIGNED => 1, -HANDLE => $string_handle
  );
  
  my $pt = $dba->get_ProteinTreeAdaptor()->fetch_node_by_node_id(2);
  
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

Used as a way of emitting Compara ProteinTrees in a format which conforms
to L<PhyloXML|http://www.phyloxml.org/>. The code is built to work with
instances of L<Bio::EnsEMBL::Compara::ProteinTree> but can be extended to
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

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 LICENSE

 Copyright (c) 1999-2011 The European Bioinformatics Institute and
 Genome Research Limited.  All rights reserved.

 This software is distributed under a modified Apache license.
 For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <dev@ensembl.org>.

 Questions may also be sent to the Ensembl help desk at
 <helpdesk@ensembl.org>.

=cut

use strict;
use warnings;

use base qw(Bio::EnsEMBL::Compara::Graph::BaseXMLWriter);

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(check_ref wrap_array);

my $phylo_uri = 'http://www.phyloxml.org';

=pod

=head2 new()

  Arg[CDNA]             : Boolean; indicates if we want CDNA emitted or peptide.
                          Defaults to B<true>. 
  Arg[SOURCE]           : String; the source of the stable identifiers.
                          Defaults to B<Unknown>.
  Arg[ALIGNED]          : Boolean; indicates if we want to emit aligned
                          sequence. Defaults to B<false>.
  Arg[NO_SEQUENCES]     : Boolean; indicates we want to ignore sequence 
                          dumping. Defaults to B<false>.
  Arg[HANDLE]           : IO::Handle; pass in an instance of IO::File or
                          an instance of IO::String so long as it behaves
                          the same as IO::Handle. Can be left blank in 
                          favour of the -FILE parameter
  Arg[FILE]             : Scalar; file to write to              
  Description : Creates a new tree writer object. 
  Returntype  : Instance of the writer
  Exceptions  : None
  Example     : my $w = Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter->new(
                  -SOURCE => 'Ensembl', -ALIGNED => 1, -HANDLE => $handle
                );
  Status      : Stable  
  
=cut

sub new {
  my ($class, @args) = @_;
  $class = ref($class) || $class;
  my $self = $class->SUPER::new(@args);
  
  my ($cdna, $source, $aligned, $no_sequences) = 
    rearrange([qw(cdna source aligned no_sequencess)], @args);

  $source ||= 'Unknown';
  $cdna = 1 unless defined $cdna;
  if( ($cdna || $aligned) && $no_sequences) {
    warning "-CDNA or -ALIGNED was specified but so was -NO_SEQUENCES. Will ignore sequences";
  }
  
  $self->cdna($cdna);
  $self->source($source);
  $self->aligned($aligned);
  $self->no_sequences($no_sequences);
  
  return $self;
}

=pod

=head2 end_element()

  Description : The starting/final element name
  Returntype : String; phyloxml
  Exceptions : None
  Status     : Stable

=cut

sub end_element {
  my ($self) = @_;
  return 'phyloxml';
}

=pod

=head2 namespaces()

Provides the namespaces used in this writer (the PhyloXML namespace)

=cut

sub namespaces {
  my ($self) = @_;
  return {
    $phylo_uri => ''
  };
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

=head2 source()

  Arg[0] : The value to set this to
  Description : Indicates the source of the stable identifiers for the 
                peptides.
  Returntype : String
  Exceptions : None
  Status     : Stable
  
=cut

sub source {
  my ($self, $source) = @_;
  $self->{source} = $source if defined $source;
  return $self->{source};
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

=pod

=head2 write_trees()

  Arg[0]      : The tree to write. Can be a single Tree or an ArrayRef
  Description : Writes a tree into the backing document representation
  Returntype  : None
  Exceptions  : Possible if there is an issue with retrieving data from the tree
  instance
  Example     : $writer->write_trees($tree);
                $writer->write_trees([$tree_one, $tree_two]);
  Status      : Stable  
  
=cut

sub write_trees {
  my ($self, $trees) = @_;
  $trees = wrap_array($trees);
  foreach my $tree (@{$trees}) {
    $self->_write_tree($tree);
  }
  return;
}

########### PRIVATE

sub _write_opening {
  my ($self, $w) = @_;
  my $xsi_uri = $self->xml_schema_namespace();
  $w->xmlDecl("UTF-8");
  $w->forceNSDecl($phylo_uri);
  $w->forceNSDecl($xsi_uri);
  $w->startTag('phyloxml', [$xsi_uri, 'schemaLocation'] => 
   "${phylo_uri} ${phylo_uri}/1.10/phyloxml.xsd");
  return;
}

sub _write_tree {
  my ($self, $tree) = @_;
  
  my $w = $self->_writer();
  
  my %attr = (rooted => 'true');
  
  if(check_ref($tree, 'Bio::EnsEMBL::Compara::ProteinTree')) {
    $attr{type} = 'gene tree';
  }
  
  $w->startTag('phylogeny', %attr);
  $w->dataElement('id', $tree->stable_id()) if $tree->stable_id();
  $self->_process($tree);
  $w->endTag('phylogeny');
  
  $tree->release_tree();
  return;
}

sub _process {
  my ($self, $node) = @_;
  my ($tag, $attributes) = @{$self->_dispatch_tag($node)};
  $self->_writer()->startTag($tag, %{$attributes});
  $self->_dispatch_body($node);
  $self->_writer()->endTag($tag);
  return; 
}

sub _dispatch_tag {
  my ($self, $node) = @_;
  if(check_ref($node, 'Bio::EnsEMBL::Compara::AlignedMember')) {
    return $self->_alignedmember_tag($node);
  }
  elsif(check_ref($node, 'Bio::EnsEMBL::Compara::NestedSet')) {
    return $self->_nestedset_tag($node);
  }
  my $ref = ref($node);
  throw("Cannot process type $ref");
}

sub _dispatch_body {
  my ($self, $node) = @_;
  if(check_ref($node, 'Bio::EnsEMBL::Compara::AlignedMember')) {
    $self->_alignedmember_body($node);
  }
  elsif(check_ref($node, 'Bio::EnsEMBL::Compara::NestedSet')) {
    $self->_nestedset_body($node);
  }
  else {
    my $ref = ref($node);
    throw("Cannot process type $ref");
  }
  return;
}

###### PROCESSORS

#tags return [ 'tag', {attributes} ]

sub _nestedset_tag {
  my ($self, $node) = @_;
  return ['clade', {branch_length => $node->distance_to_parent()}];
}

#body writes data
sub _nestedset_body {
  my ($self, $node, $defer_taxonomy) = @_;
  
  my $dup   = $node->get_tagvalue('Duplication');
  my $dubi  = $node->get_tagvalue('dubious_duplication');
  my $boot  = $node->get_tagvalue('Bootstrap');
  my $taxid = $node->get_tagvalue('taxon_id');
  my $tax   = $node->get_tagvalue('taxon_name');
  
  my $w = $self->_writer();
  
  if($boot) {
    $w->dataElement('confidence', $boot, 'type' => 'bootstrap');
  }
  
  if(!$defer_taxonomy && $taxid) {
    $self->_write_taxonomy($taxid, $tax);
  }
  
  if($dup) {
    $w->startTag('events');
    $w->dataElement('type', 'speciation_or_duplication');
    $w->dataElement('duplications', 1);
    $w->endTag();
  }
  
  if($dubi) {
    $w->dataElement('property', $dubi, 
      'datatype' => 'xsd:int', 
      'ref' => 'Compara:dubious_duplication', 
      'applies_to' => 'clade'
    );
  }
  
  if($node->get_child_count()) {
    foreach my $child (@{$node->children()}) {
      $self->_process($child);
    }
  }
  
  return;
}

sub _alignedmember_tag {
  my ($self, $node) = @_;
  return $self->_nestedset_tag($node);
}

sub _alignedmember_body {
  my ($self, $protein) = @_;
  
  my $w = $self->_writer();
  $self->_nestedset_body($protein , 1); #Used to defer taxonomy writing
  
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
  my $location = sprintf('%s:%d-%d',$gene->chr_name(), $gene->chr_start(), $gene->chr_end());
  $w->dataElement('location', $location);
  
  if(!$self->no_sequences()) {
    my $mol_seq;
    if($self->aligned()) {
      $mol_seq = ($self->cdna()) ? $protein->cdna_alignment_string() : $protein->alignment_string();
    }
    else {
      $mol_seq = ($self->cdna()) ? $protein->sequence_cds() : $protein->sequence(); 
    }
    $mol_seq =~ s/\s+//g if $self->cdna();

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

sub _write_taxonomy {
  my ($self, $id, $name) = @_;
  my $w = $self->_writer();
  $w->startTag('taxonomy');
  $w->dataElement('id', $id);
  $w->dataElement('scientific_name', $name);
  $w->endTag();
  return;
}


1;