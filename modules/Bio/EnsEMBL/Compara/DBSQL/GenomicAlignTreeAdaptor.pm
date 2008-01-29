=head1 NAME

GenomicAlignTreeAdaptor - Object used to store and retrieve GenomicAlignTrees to/from the databases

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONTACT

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::GenomicAlignTreeAdaptor;

use strict;
use Bio::EnsEMBL::Compara::GenomicAlignTree;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;
our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::NestedSetAdaptor);

###########################
# FETCH methods
###########################

=head2 fetch_all_by_MethodLinkSpeciesSet_DnaFrag

=cut

sub fetch_all_by_MethodLinkSpeciesSet {
  my ($self, $method_link_species_set, $limit_number, $limit_index_start) = @_;
  my $genomic_align_trees = [];

  throw("[$method_link_species_set] is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
      unless ($method_link_species_set and ref $method_link_species_set and
          $method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
  my $method_link_species_set_id = $method_link_species_set->dbID;
  throw("[$method_link_species_set_id] has no dbID") if (!$method_link_species_set_id);

  my $genomic_align_blocks = [];
  my $genomic_align_block_adaptor = $self->db->get_GenomicAlignBlockAdaptor();
  my $sql = qq{
          SELECT
              ga.genomic_align_block_id
          FROM
              genomic_align_tree gat,
              genomic_align ga
          WHERE
              gat.parent_id = 0 AND
              gat.node_id = ga.genomic_align_id AND
              ga.method_link_species_set_id = $method_link_species_set_id
      };
  if ($limit_number && $limit_index_start) {
    $sql .= qq{ LIMIT $limit_index_start , $limit_number };
  } elsif ($limit_number) {
    $sql .= qq{ LIMIT $limit_number };
  }

  my $sth = $self->prepare($sql);
  $sth->execute();
  my ($genomic_align_block_id);
  $sth->bind_columns(\$genomic_align_block_id);

  while ($sth->fetch) {
    my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
            -adaptor => $genomic_align_block_adaptor,
            -dbID => $genomic_align_block_id,
            -method_link_species_set_id => $method_link_species_set_id,
        );
    push(@$genomic_align_blocks, $this_genomic_align_block);
  }

  foreach my $this_genomic_align_block (@$genomic_align_blocks) {
    my $this_genomic_align_tree = $self->fetch_by_GenomicAlignBlock($this_genomic_align_block);
    if ($this_genomic_align_tree) {
      if ($this_genomic_align_block->reference_genomic_align) {
        $this_genomic_align_tree->reference_genomic_align($this_genomic_align_block->reference_genomic_align);
      }
      $this_genomic_align_tree->sorted_children;
      push(@$genomic_align_trees, $this_genomic_align_tree);
    }
  }

  return $genomic_align_trees;
}


=head2 fetch_all_by_MethodLinkSpeciesSet_DnaFrag

=cut

sub fetch_all_by_MethodLinkSpeciesSet_DnaFrag {
  my ($self, $method_link_species_set, $dnafrag, $start, $end, $limit_number, $limit_index_start, $restrict) = @_;
  my $genomic_align_trees = [];

  my $genomic_align_block_adaptor = $self->db->get_GenomicAlignBlockAdaptor();
  my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
      $method_link_species_set, $dnafrag, $start, $end, $limit_number, $limit_index_start);
  foreach my $this_genomic_align_block (@$genomic_align_blocks) {
    my $this_genomic_align_tree = $self->fetch_by_GenomicAlignBlock($this_genomic_align_block);
    if ($this_genomic_align_tree) {
#         print " . ", join("\n . ", @{$this_genomic_align_block->get_all_GenomicAligns}), "\n";
#         print join("\n : ", @{$this_genomic_align_tree->get_all_GenomicAligns}), "\n";
#         print " * ", $this_genomic_align_tree->reference_genomic_align, "\n";
#       if ($this_genomic_align_block->reference_genomic_align) {
#         $this_genomic_align_tree->reference_genomic_align($this_genomic_align_block->reference_genomic_align);
#         print " * ", $this_genomic_align_tree->reference_genomic_align, "\n";
#       }
      $this_genomic_align_tree->sorted_children;
      if (defined($start) and defined($end) and $restrict) {
        $this_genomic_align_tree = $this_genomic_align_tree->restrict_between_reference_positions(
            $start, $end, undef, "skip_empty_genomic_aligns");
      }
      push(@$genomic_align_trees, $this_genomic_align_tree);
    }
  }

  return $genomic_align_trees;
}


=head2 fetch_by_GenomicAlign

=cut

sub fetch_by_GenomicAlignBlock {
  my ($self, $genomic_align_block) = @_;

  if (!UNIVERSAL::isa($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignBlock")) {
    throw("[$genomic_align_block] must be a Bio::EnsEMBL::Compara::GenomicAlignBlock object");
  }

  ## node_id in the genomic_align_tree table corresponds to the genomic_align_id of
  ## any of the Bio::EnsEMBL::Compara::GenomicAlign objects underlying this
  ## Bio::EnsEMBL::Compara::GenomicAlignBlock.
  my $node_id = $genomic_align_block->get_all_GenomicAligns->[0]->dbID;
#   print STDERR "NODE ", $node_id, "\n";

  my $node = $self->fetch_node_by_node_id($node_id);
  if (!$node) {
    warning("Broken link for genomic_align #$node_id\n");
    return undef;
  }

  ## root_id point to the root of this tree:
  my $root = $self->fetch_node_by_node_id($node->root->node_id);
#   print STDERR "ROOT ", $root->node_id, "\n";

  $root->{genomic_align_array} = [map {$_->genomic_align} @{$root->get_all_sorted_genomic_align_nodes}];
  foreach my $this_genomic_align (map {$_->genomic_align} @{$root->get_all_sorted_genomic_align_nodes}) {
    $this_genomic_align->{genomic_align_block} = $root;
  }

  if ($genomic_align_block->reference_genomic_align) {
    if (!$genomic_align_block->get_original_strand()) {
      $root->reverse_complement();
    }
    my $ref_genomic_align = $genomic_align_block->reference_genomic_align;
    foreach my $this_genomic_align (map {$_->genomic_align} @{$root->get_all_sorted_genomic_align_nodes}) {
#       print $genomic_align_block->reference_genomic_align->get_Slice->name, " -- ", $this_genomic_align->get_Slice->name, "\n";
      if ($this_genomic_align->genome_db->name eq $ref_genomic_align->genome_db->name and
          $this_genomic_align->dnafrag->name eq $ref_genomic_align->dnafrag->name and
          $this_genomic_align->dnafrag_start eq $ref_genomic_align->dnafrag_start and
          $this_genomic_align->dnafrag_end eq $ref_genomic_align->dnafrag_end and
          $this_genomic_align->dnafrag_strand eq $ref_genomic_align->dnafrag_strand and
          $this_genomic_align->cigar_line eq $ref_genomic_align->cigar_line) {
        $root->reference_genomic_align($this_genomic_align);
        last;
      }
    }
  }

  return $root;
}


###########################
# STORE methods
###########################

=head2 store

  Arg 1       : Bio::EnsEMBL::Compara::GenomicAlignTree $root
  Arg[2]      : [optional] bool $skip_left_right_indexes
  Example     : $gata->store($root);
  Description : This method stores the GenomicAlign in the tree,
                the corresponding GenomicAlignBlock(s) and all
                the GenomicAlignTree nodes in this tree. If you set
                the $skip_left_right_indexes flag to any true value,
                the left and right indexes in the tree won't be build
                at this point. This may be usefull for production
                purposes as building the indexes requires to lock the
                table and can hamper other processes storing data at
                that time.
  Exceptions  : throws if any of the nodes of the tree misses its
                GenomicAlign object or this one misses its
                GenomicAlignBlock objects.
  Caller      : general

=cut

sub store {
  my ($self, $node, $skip_left_right_indexes) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::GenomicAlignTree')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::GenomicAlignTree] not a $node");
  }

  ## Get the full list of GenomicAlignBlock objects in this tree
  my $genomic_align_blocks;
  foreach my $this_node (@{$node->get_all_nodes}) {
    my $genomic_align = $this_node->genomic_align;
    if (!$genomic_align) {
      throw("No Bio::EnsEMBL::Compara::GenomicAlign found for $this_node");
    }
    my $genomic_align_block = $genomic_align->genomic_align_block;
    if (!$genomic_align_block) {
      throw("No Bio::EnsEMBL::Compara::GenomicAlignBlock found for $this_node");
    }
    $genomic_align_blocks->{$genomic_align_block} = $genomic_align_block
  }

  ## Store all the GenomicAlignBlock objects (this stores the GenomicAlign objects as well)
  my $genomic_align_block_adaptor = $self->db->get_GenomicAlignBlockAdaptor();
  foreach my $this_genomic_align_block (values %$genomic_align_blocks) {
    if (!$this_genomic_align_block->method_link_species_set) {
      $this_genomic_align_block->method_link_species_set(
          $this_genomic_align_block->get_all_GenomicAligns->[0]->method_link_species_set);
    }
    $genomic_align_block_adaptor->store($this_genomic_align_block);
  }

  ## Store this node and, recursivelly, all the sub nodes
  $self->store_node($node);

  ## Set and store the left and right indexes unless otherwise stated
  if (!$skip_left_right_indexes) {
    $self->sync_tree_leftright_index($node);
    $self->update_subtree($node);
  }

  return $node->node_id;
}


sub store_node {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::GenomicAlignTree')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::GenomicAlignTree] not a $node");
  }

  my $parent_id = 0;
  my $root_id = 0;
  if($node->parent) {
    $parent_id = $node->parent->node_id ;
    $root_id = $node->root->node_id;
  }
  #printf("inserting parent_id = %d, root_id = %d\n", $parent_id, $root_id);
  
  if (!$node->genomic_align or !$node->genomic_align->dbID) {
    throw("Cannot store before setting the genomic_align ID");
  }
  $node->node_id($node->genomic_align->dbID);
  my $sth = $self->prepare("INSERT INTO genomic_align_tree 
                             (node_id,
                              parent_id,
                              root_id,
                              left_index,
                              right_index,
                              distance_to_parent)  VALUES (?,?,?,?,?,?)");
  $sth->execute($node->node_id, $parent_id, $root_id, $node->left_index, $node->right_index, $node->distance_to_parent);

  $node->adaptor($self);
  $sth->finish;

  foreach my $this_child (@{$node->children}) {
    $self->store_node($this_child);
  }

  return $node->node_id;
}

sub update_neighbourhood_data {
  my ($self, $node, $no_recursivity) = @_;

  my $sth = $self->prepare("UPDATE genomic_align_tree
      SET left_node_id = ?, right_node_id = ?
      WHERE node_id = ?");
  $sth->execute($node->left_node_id, $node->right_node_id, $node->node_id);

  if (!$no_recursivity) {
    foreach my $this_children (@{$node->children}) {
      $self->update_neighbourhood_data($this_children);
    }
  }

  return $node;
}

sub columns {
  my $self = shift;
  return ['gat.node_id',
          'gat.parent_id',
          'gat.root_id',
          'gat.left_index',
          'gat.right_index',
          'gat.distance_to_parent',
          'gat.left_node_id',
          'gat.right_node_id',
          ];
}

sub tables {
  my $self = shift;
  return [['genomic_align_tree', 'gat']];
}

sub left_join_clause {
  return "";
}

sub default_where_clause {
  return "";
}


sub create_instance_from_rowhash {
  my $self = shift;
  my $rowhash = shift;

  my $node = new Bio::EnsEMBL::Compara::GenomicAlignTree;

  $self->init_instance_from_rowhash($node, $rowhash);

  return $node;
}


sub init_instance_from_rowhash {
  my $self = shift;
  my $node = shift;
  my $rowhash = shift;

  #SUPER is NestedSetAdaptor
  $self->SUPER::init_instance_from_rowhash($node, $rowhash);
  $node->left_node_id($rowhash->{'left_node_id'});
  $node->right_node_id($rowhash->{'right_node_id'});

  $node->adaptor($self);

  return $node;
}


##########################################################
#
# explicit method forwarding to MemberAdaptor
#
##########################################################

sub _fetch_sequence_by_id {
  my $self = shift;
  return $self->db->get_MemberAdaptor->_fetch_sequence_by_id(@_);
}

sub fetch_gene_for_peptide_member_id { 
  my $self = shift;
  return $self->db->get_MemberAdaptor->fetch_gene_for_peptide_member_id(@_);
}

sub fetch_peptides_for_gene_member_id {
  my $self = shift;
  return $self->db->get_MemberAdaptor->fetch_peptides_for_gene_member_id(@_);
}

sub fetch_longest_peptide_member_for_gene_member_id {
  my $self = shift;
  return $self->db->get_MemberAdaptor->fetch_longest_peptide_member_for_gene_member_id(@_);
}


1;
