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

package Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter;

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter

=head1 SYNOPSIS

This is a base class for writing compara trees in PhyloXML format.
See Bio::EnsEMBL::Compara::Graph::GeneTreePhyloXMLWriter for a specific use of this module


=head1 DESCRIPTION

Used as a way of emitting Compara trees in a format which conforms
to L<PhyloXML|http://www.phyloxml.org/>.

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

use base qw(Bio::EnsEMBL::Compara::Graph::BaseXMLWriter);

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(check_ref wrap_array);

my $phylo_uri = 'http://www.phyloxml.org';

=pod

=head2 new()

  Arg[SOURCE]           : String; the source of the stable identifiers.
                          Defaults to B<Unknown>.
  Arg[HANDLE]           : IO::Handle; pass in an instance of IO::File or
                          an instance of IO::String so long as it behaves
                          the same as IO::Handle. Can be left blank in
                          favour of the -FILE parameter
  Arg[FILE]             : Scalar; file to write to
  Arg[NO_RELEASE_TREES] : Boolean; if set to true this will force the writer
                          to avoid calling C<release_tree()> on every tree
                          given. Defaults to false
  Arg[NO_BRANCH_LENGTHS]: Boolean; if set to true no branch length will written.
                          Defaults to B<false>.

  Description : Creates a new tree writer object.
  Returntype  : Instance of the writer
  Exceptions  : None
  Example     : my $w = Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter->new(
                  -SOURCE => 'Ensembl', -HANDLE => $handle
                );
  Status      : Stable

=cut

sub new {
  my ($class, @args) = @_;
  $class = ref($class) || $class;
  my $self = $class->SUPER::new(@args);

  my ($source, $no_release_trees, $no_branch_lengths) = 
    rearrange([qw(source no_release_trees no_branch_lengths)], @args);

  $source ||= 'Unknown';

  $self->source($source);
  $self->no_release_trees($no_release_trees);
  $self->no_branch_lengths($no_branch_lengths);

  return $self;
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

=head2 no_release_trees()

  Arg [0] : Boolean; indiciates if we need to avoid releasing trees
  Returntype : Boolean
  Exceptions : None
  Status     : Stable

=cut

sub no_release_trees {
  my ($self, $no_release_trees) = @_;
  $self->{no_release_trees} = $no_release_trees if defined $no_release_trees;
  return $self->{no_release_trees};
}

=pod

=head2 no_branch_lengths()

  Arg [0] : Boolean; indiciates we do not wish to add branch lengths
  Returntype : Boolean
  Exceptions : None
  Status     : Stable

=cut

sub no_branch_lengths {
  my ($self, $no_branch_lengths) = @_;
  $self->{no_branch_lengths} = $no_branch_lengths if defined $no_branch_lengths;
  return $self->{no_branch_lengths};
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
  my ($self) = @_;
  my $w = $self->_writer;
  my $xsi_uri = $self->xml_schema_namespace();
  $w->xmlDecl("UTF-8");
  $w->forceNSDecl($phylo_uri);
  $w->forceNSDecl($xsi_uri);
  $w->startTag("phyloxml", [$xsi_uri, 'schemaLocation'] =>
   "${phylo_uri} ${phylo_uri}/1.10/phyloxml.xsd");
  return;
}

sub _write_closing {
  my ($self) = @_;
  $self->_writer()->endTag("phyloxml");
}

sub _write_tree {
  my ($self, $tree) = @_;

  my $w = $self->_writer();

  my %attr = (rooted => 'true');
  $attr{type} = $self->tree_type();

  $w->startTag('phylogeny', %attr);
  $self->_process($tree->root);
  $self->tree_elements($tree);
  $w->endTag('phylogeny');

  $tree->release_tree() if ((! $self->no_release_trees) && ($tree->can('release_tree')));

  return;
}

sub _process {
  my ($self, $node) = @_;
  my ($tag, $attributes) = @{$self->dispatch_tag($node)};
  $self->_writer()->startTag($tag, %{$attributes});
  $self->dispatch_body($node);

    foreach my $child (@{$node->sorted_children()}) {
      $self->_process($child);
    }

  $self->_writer()->endTag($tag);
  return;
}

sub _write_genome_db {
  my ($self, $gdb) = @_;
  my $w = $self->_writer();
  $w->startTag('taxonomy');
  $w->dataElement('id', $gdb->taxon_id);
  $w->dataElement('scientific_name', $gdb->get_scientific_name('unique'));
  $w->dataElement('common_name', $gdb->display_name);
  $w->endTag();
}

sub _write_species_tree_node {
  my ($self, $stn) = @_;
  my $w = $self->_writer();
  $w->startTag('taxonomy');
  $w->dataElement('id', $stn->taxon_id) if $stn->taxon_id;
  $w->dataElement('scientific_name', $stn->get_scientific_name);
  my $common_name = $stn->get_common_name;
  $w->dataElement('common_name', $common_name) if $common_name;
  $w->endTag();
}

# NB: this methods relies on parameters that *must* be defined in self:
#     no_sequences(), cdna(), and is_aligned()
sub _write_seq_member {
  my ($self, $protein) = @_;

  my $w = $self->_writer();

  my $gene = $protein->gene_member();

  #Stable IDs
  $w->dataElement('name', $gene->stable_id());

  #Taxon (GenomeDB)
  $self->_write_genome_db($protein->genome_db);

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
      # alignment_string() is not able to remove gaps found in all the other sequences, so these may need to be cached
      $mol_seq = $self->{_cached_seq_aligns}->{$protein->stable_id}
                 || ($self->cdna() ? $protein->alignment_string('cds') : $protein->alignment_string());
    }
    else {
      $mol_seq = ($self->cdna() ? $protein->other_sequence('cds') : $protein->sequence());
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

  if (not $protein->isa('Bio::EnsEMBL::Compara::GeneTreeMember')) {
      $w->dataElement('property', $protein->perc_id,
          'datatype' => 'xsd:float',
          'ref' => 'Compara_homology:perc_identity',
          'applies_to' => 'clade',
      );
  }

  return;
}



1;
