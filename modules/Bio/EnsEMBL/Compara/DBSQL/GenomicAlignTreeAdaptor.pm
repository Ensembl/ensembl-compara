=head1 NAME

GenomicAlignTreeAdaptor - Object used to store and retrieve GenomicAlignTrees to/from the databases

=head1 SYNOPSIS

=head1 DESCRIPTION

This version of the module is still very experimental.

=head1 CONTACT

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::GenomicAlignTreeAdaptor;

use strict;
use Bio::EnsEMBL::Compara::GenomicAlignTree;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::GenomicAlign;
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

  my $constraint = "WHERE ga.method_link_species_set_id = $method_link_species_set_id AND gat.parent_id = 0";
  my $final_clause = "";
  if ($limit_number) {
    $limit_index_start = 0 if (!$limit_index_start);
    $final_clause = "LIMIT $limit_index_start, $limit_number";
  }
  $genomic_align_trees = $self->_generic_fetch($constraint, undef, $final_clause);

  return $genomic_align_trees;
}


=head2 fetch_all_by_MethodLinkSpeciesSet_DnaFrag

=cut

sub fetch_all_by_MethodLinkSpeciesSet_DnaFrag {
  my ($self, $method_link_species_set, $dnafrag, $start, $end, $limit_number, $limit_index_start, $restrict) = @_;

  ## Get internal IDs from the objects
  my $method_link_species_set_id = $method_link_species_set->dbID;
  my $dnafrag_id = $dnafrag->dbID;

  ###########################################################################
  ## FIRST STEP:
  ## The query looks for GenomicAlign entries in the genomic region of interest
  ## and links to the GenomicAlignGroup and GenomicAlignTree entries. We extract
  ## the list of node IDs for the root of the GenomicAlignTrees
  ###########################################################################
  my $constraint = "WHERE ga.method_link_species_set_id = $method_link_species_set_id
      AND ga.dnafrag_id = $dnafrag_id";

  if (defined($start) and defined($end)) {
    my $max_alignment_length = $method_link_species_set->max_alignment_length;
    my $lower_bound = $start - $max_alignment_length;
    $constraint .= qq{
            AND ga.dnafrag_start <= $end
            AND ga.dnafrag_start >= $lower_bound
            AND ga.dnafrag_end >= $start
        };
  }

  my $sql = $self->_construct_sql_query($constraint);
  my $sth = $self->prepare($sql);
  $sth->execute();
  my $ref_to_root_hash = {};
  while(my $rowhash = $sth->fetchrow_hashref) {
    my $root_node_id = $rowhash->{root_id};
    my $reference_genomic_align_id = $rowhash->{genomic_align_id};
    $ref_to_root_hash->{$reference_genomic_align_id} = $root_node_id;
    print "REF $reference_genomic_align_id} = $root_node_id\n";
  }
  $sth->finish();
  return [] if (!%$ref_to_root_hash);

  ###########################################################################
  ## SECOND STEP:
  ## Get all the nodes for the root IDs we got in step 1
  ###########################################################################
  my $genomic_align_trees = [];
  while (my ($reference_genomic_align_id, $root_node_id) = each %$ref_to_root_hash) {
    $constraint = "WHERE gat.root_id = $root_node_id";
    my $genomic_align_nodes = $self->_generic_fetch($constraint);
    my $root = $self->_build_tree_from_nodes($genomic_align_nodes);
    my $all_leaves = $root->get_all_leaves;
    for (my $i = 0; $i < @$all_leaves; $i++) {
      my $this_leaf = $all_leaves->[$i];
      my $all_genomic_aligns = $this_leaf->get_all_GenomicAligns;
      foreach my $this_genomic_align (@$all_genomic_aligns) {
        if ($this_genomic_align->dbID == $reference_genomic_align_id) {
          $root->reference_genomic_align($this_genomic_align);
          $root->reference_genomic_align_node($this_leaf);
          if (@$all_genomic_aligns > 1) {
            ## Reference hits a composite GenomicAlign. We have to restrict the tree
            my $cigar_line = $this_genomic_align->cigar_line;
            my ($start, $end) = (1, $this_genomic_align->length);
            if ($cigar_line =~ /^(\d*)X/) {
              $start += ($1 eq "")?1:$1;
            }
            if ($cigar_line =~ /(\d*)X$/) {
              $end -= ($1 eq "")?1:$1;
            }
            $root = $root->restrict_between_alignment_positions($start, $end, "skip");
          }
          $i += @$all_leaves; # exit external loop as well
          last;
        }
      }
    }
    push(@$genomic_align_trees, $root);
  }

  return $genomic_align_trees;
}


=head2 fetch_all_by_MethodLinkSpeciesSet_Slice

  Status:     At risk

=cut

sub fetch_all_by_MethodLinkSpeciesSet_Slice {
  my ($self, $method_link_species_set, $reference_slice, $limit_number, $limit_index_start, $restrict) = @_;
  my $all_genomic_align_trees = []; # Returned value


  ###########################################################################
  ## The strategy here is very much the same as in the corresponging method
  ## of the Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor
  ###########################################################################
  my $genome_db = $self->db->get_GenomeDBAdaptor->fetch_by_Slice($reference_slice);
  my $dnafrag_adaptor = $self->db->get_DnaFragAdaptor($reference_slice);

  my $projection_segments = $reference_slice->project('toplevel');
  return [] if(!@$projection_segments);

  foreach my $this_projection_segment (@$projection_segments) {
    my $this_slice = $this_projection_segment->to_Slice;
    my $coord_system_name = $this_slice->coord_system->name;
    my $this_dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name(
            $genome_db, $this_slice->seq_region_name
        );
    next if (!$this_dnafrag);

    my $these_genomic_align_trees = $self->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
            $method_link_species_set,
            $this_dnafrag,
            $this_slice->start,
            $this_slice->end,
            $limit_number,
            $limit_index_start,
            $restrict
        );

    my $top_slice = $this_slice->seq_region_Slice;
    throw if ($top_slice->name ne $this_slice->seq_region_Slice->name);
    print join("\n", $top_slice->name, $this_slice->seq_region_Slice->name), "\n";

    # need to convert features to requested coord system
    # if it was different then the one we used for fetching

    if($top_slice->name ne $reference_slice->name) {
      foreach my $this_genomic_align_tree (@$these_genomic_align_trees) {
        my $feature = new Bio::EnsEMBL::Feature(
                -slice => $top_slice,
                -start => $this_genomic_align_tree->reference_genomic_align->dnafrag_start,
                -end => $this_genomic_align_tree->reference_genomic_align->dnafrag_end,
                -strand => $this_genomic_align_tree->reference_genomic_align->dnafrag_strand
            );
        $feature = $feature->transfer($reference_slice);
	next if (!$feature);
        $this_genomic_align_tree->reference_slice($reference_slice);
        $this_genomic_align_tree->reference_slice_start($feature->start);
        $this_genomic_align_tree->reference_slice_end($feature->end);
        $this_genomic_align_tree->reference_slice_strand($reference_slice->strand);
        $this_genomic_align_tree->reverse_complement()
            if ($reference_slice->strand != $this_genomic_align_tree->reference_genomic_align->dnafrag_strand);
        push (@$all_genomic_align_trees, $this_genomic_align_tree);
      }
    } else {
#       foreach my $this_genomic_align_block (@$these_genomic_align_blocks) {
#         $this_genomic_align_block->reference_slice($top_slice);
#         $this_genomic_align_block->reference_slice_start(
#             $this_genomic_align_block->reference_genomic_align->dnafrag_start);
#         $this_genomic_align_block->reference_slice_end(
#             $this_genomic_align_block->reference_genomic_align->dnafrag_end);
#         $this_genomic_align_block->reference_slice_strand($reference_slice->strand);
#         $this_genomic_align_block->reverse_complement()
#             if ($reference_slice->strand != $this_genomic_align_block->reference_genomic_align->dnafrag_strand);
#         push (@$all_genomic_align_blocks, $this_genomic_align_block);
#       }
    }
  }

  return $all_genomic_align_trees;
}

=head2 fetch_by_GenomicAlignBlock

=cut

sub fetch_by_GenomicAlignBlock {
  my ($self, $genomic_align_block) = @_;

  my $genomic_align_block_id = $genomic_align_block->dbID;

  my $join = [
      [["genomic_align_tree","gat2"], "gat2.root_id = gat.node_id", undef],
      [["genomic_align_group","gag2"], "gag2.group_id = gat2.node_id", undef],
      [["genomic_align","ga2"], "ga2.genomic_align_id = gag2.genomic_align_id", undef],
    ];
  my $constraint = "WHERE ga2.genomic_align_block_id = $genomic_align_block_id";
  my $genomic_align_trees = $self->_generic_fetch($constraint, $join);

  if (@$genomic_align_trees > 1) {
    warning("Found more than 1 tree. This shouldn't happen. Returning the first one only");
  }
  if (@$genomic_align_trees == 0) {
    return;
  }
  my $genomic_align_tree = $genomic_align_trees->[0];
  if ($genomic_align_block->reference_genomic_align) {
    my $ref_genomic_align = $genomic_align_block->reference_genomic_align;
    LEAF: foreach my $this_leaf (@{$genomic_align_tree->get_all_leaves}) {
      foreach my $this_genomic_align (@{$this_leaf->get_all_GenomicAligns}) {
        if ($this_genomic_align->genome_db->name eq $ref_genomic_align->genome_db->name and
            $this_genomic_align->dnafrag->name eq $ref_genomic_align->dnafrag->name and
            $this_genomic_align->dnafrag_start eq $ref_genomic_align->dnafrag_start and
            $this_genomic_align->dnafrag_end eq $ref_genomic_align->dnafrag_end) {
          $genomic_align_tree->reference_genomic_align_node($this_leaf);
          $genomic_align_tree->reference_genomic_align($this_genomic_align);
          last LEAF;
        }
      }
    }
  }
  if ($genomic_align_block->reference_slice) {
    $genomic_align_tree->reference_slice($genomic_align_block->reference_slice);
    $genomic_align_tree->reference_slice_start($genomic_align_block->reference_slice_start);
    $genomic_align_tree->reference_slice_end($genomic_align_block->reference_slice_end);
    $genomic_align_tree->reference_slice_strand($genomic_align_block->reference_slice_strand);
  }

  #if the genomic_align_block has been complemented, then complement the tree
  if ($genomic_align_block->get_original_strand == 0) {
      $genomic_align_tree->reverse_complement;
  }

  return $genomic_align_tree;
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
                This method expects a structure like this:
                GENOMIC_ALIGN_TREE->
                  - GENOMIC_ALIGN_GROUP->
                      - GENOMIC_ALIGNs...
                  - GENOMIC_ALIGN_TREE->
                      - GENOMIC_ALIGN_GROUP->
                          - GENOMIC_ALIGNs...
                      - GENOMIC_ALIGN_TREE->
                          - GENOMIC_ALIGN_GROUP->
                              - GENOMIC_ALIGNs...
                      - GENOMIC_ALIGN_TREE->
                          - GENOMIC_ALIGN_GROUP->
                              - GENOMIC_ALIGN...
                  - GENOMIC_ALIGN_TREE->
                      - GENOMIC_ALIGN_GROUP->
                          - GENOMIC_ALIGN...

                I.e. each node has 1 GenomicAlignGroup containing 1 or
                more GenomicAligns and optionally 2 GenomicAlignTree objects
                representing the sub_nodes. These will also contain 1
                GenomicAlignGroup containing 1 or more GenomicAligns, etc.
                No GenomicAlignBlock is expected. These will be created
                and stored by this method.

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

  ## Check the tree
  foreach my $this_node (@{$node->get_all_nodes}) {
    throw "[$this_node] has no GenomicAlignGroup" if (!$this_node->genomic_align_group);
    throw "[$this_node] has no GenomicAligns" if (!$this_node->get_all_GenomicAligns);
    throw "[$this_node] does not belong to this tree" if ($this_node->root ne $node);
  }

  ## Create and store all the GenomicAlignBlock objects (this stores the GenomicAlign objects as well)
  my $genomic_align_block_adaptor = $self->db->get_GenomicAlignBlockAdaptor();
  my $ancestral_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
      -method_link_species_set => $node->get_all_GenomicAligns->[0]->method_link_species_set,
      -group_id => $node->group_id);
  my $modern_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
      -method_link_species_set => $node->get_all_GenomicAligns->[0]->method_link_species_set,
      -group_id => $node->group_id);
  foreach my $genomic_align_node (@{$node->get_all_nodes}) {
    if ($genomic_align_node->is_leaf()) {
      foreach my $this_genomic_align (@{$genomic_align_node->get_all_GenomicAligns}) {
        $modern_genomic_align_block->add_GenomicAlign($this_genomic_align);
      }
    } else {
      foreach my $this_genomic_align (@{$genomic_align_node->get_all_GenomicAligns}) {
        $ancestral_genomic_align_block->add_GenomicAlign($this_genomic_align);
      }
    }
  }
  if (@{$ancestral_genomic_align_block->get_all_GenomicAligns} > 0) {
    $genomic_align_block_adaptor->store($ancestral_genomic_align_block);
  }
  $genomic_align_block_adaptor->store($modern_genomic_align_block);
  $node->ancestral_genomic_align_block_id($ancestral_genomic_align_block->dbID);
  $node->modern_genomic_align_block_id($modern_genomic_align_block->dbID);

  ## Store this node and, recursivelly, all the sub nodes
  $self->store_node($node);

  ## Set and store the left and right indexes unless otherwise stated
  if (!$skip_left_right_indexes) {
    $self->sync_tree_leftright_index($node);
    $self->update_subtree($node);
  }

  return $node->node_id;
}

sub store_group {
    my ($self, $nodes) = @_;

    #store trees in database
    foreach my $this_node (@$nodes) {
	$self->store($this_node);
    }

    ### Check if this is defined or not!!!
    my $group_id = 
      $nodes->[0]->genomic_align_group->get_all_GenomicAligns->[0]->genomic_align_block_id;
    
    my $genomic_align_blocks = {};
    foreach my $this_node (@$nodes) {
	## Ancestral GAB
	my $ancestral_genomic_align_block_id = $this_node->genomic_align_group->
	  get_all_GenomicAligns->[0]->genomic_align_block_id;
	my $fake_ancestral_gab;
	$fake_ancestral_gab->{dbID} = $ancestral_genomic_align_block_id;
	bless $fake_ancestral_gab, "Bio::EnsEMBL::Compara::GenomicAlignBlock";
	$genomic_align_blocks->{$ancestral_genomic_align_block_id} = 
	  $fake_ancestral_gab;
	
	## Modern GAB
	my $modern_genomic_align_block_id = 
	  $this_node->get_all_leaves->[0]->genomic_align_group->
	    get_all_GenomicAligns->[0]->genomic_align_block_id;
	my $fake_modern_gab;
	$fake_modern_gab->{dbID} = $modern_genomic_align_block_id;
	bless $fake_modern_gab, "Bio::EnsEMBL::Compara::GenomicAlignBlock";
	$genomic_align_blocks->{$modern_genomic_align_block_id} = 
	  $fake_modern_gab;
    }
    my $genomic_align_block_adaptor = 
      $self->db->get_GenomicAlignBlockAdaptor;
    foreach my $gab (values %$genomic_align_blocks) {
	$genomic_align_block_adaptor->store_group_id($gab, $group_id);
    }
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

  my $genomic_align_group_adaptor = $self->db->get_GenomicAlignGroupAdaptor();
  $genomic_align_group_adaptor->store($node->genomic_align_group);

  if (!$node->genomic_align_group or !$node->genomic_align_group->dbID) {
    throw("Cannot store before setting the genomic_align_group ID");
  }
  $node->node_id($node->genomic_align_group->dbID);
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


sub delete {
  my ($self, $root) = @_;

  if (!$root) {
    throw("Nothing to delete");
  }

  if ($root->root ne $root) {
    warn("Cowardly refusing to delete a subtree only");
    return;
  }

  my $sth = $self->prepare(
      "DELETE
        genomic_align_group.*,
        genomic_align_tree.*,
        genomic_align.*,
        genomic_align_block.*
      FROM
        genomic_align_tree
        LEFT JOIN genomic_align_group ON (node_id = group_id)
        LEFT JOIN genomic_align USING (genomic_align_id)
        LEFT JOIN genomic_align_block USING (genomic_align_block_id)
      WHERE root_id = ?");
  $sth->execute($root->node_id);
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

sub set_neighbour_nodes_for_leaf {
  my ($self, $node, $flanking) = @_;
  $flanking = 1000000 if (!$flanking);

  next if (!$node->is_leaf());
  next if (!$node->genomic_align_group);
  my $genomic_aligns = $node->genomic_align_group->get_all_GenomicAligns;

  my $sth = $self->prepare("SELECT group_id, dnafrag_start, dnafrag_end, dnafrag_strand
      FROM genomic_align LEFT JOIN genomic_align_group USING (genomic_align_id)
      WHERE type = 'epo'
        AND dnafrag_id = ?
        AND method_link_species_set_id = ?
        AND dnafrag_start <= ?
        AND dnafrag_start > ?
        AND dnafrag_end >= ?
        ORDER BY dnafrag_start");

  my $genomic_align = $genomic_aligns->[0];
  my $dnafrag_start = $genomic_align->dnafrag_start;
  my $dnafrag_end = $genomic_align->dnafrag_end;

  $sth->execute(
      $genomic_align->dnafrag_id,
      $genomic_align->method_link_species_set_id,
      $dnafrag_end + $flanking,
      $dnafrag_start - $flanking - $genomic_align->method_link_species_set->max_alignment_length,
      $dnafrag_start - $flanking,
      );
  my $table = $sth->fetchall_arrayref;

  if (@$genomic_aligns == 1) {
    for (my $i = 0; $i < @$table; $i++) {
      my ($this_group_id, $this_dnafrag_start, $this_dnafrag_end, $this_dnafrag_strand) = @{$table->[$i]};
      if ($this_dnafrag_start == $dnafrag_start and $this_dnafrag_end == $dnafrag_end) {
        ## $table->[$i] correspond to the query node
        if ($this_dnafrag_strand == 1) {
          $node->left_node_id($table->[$i-1]->[0]) if ($i > 0);
          $node->right_node_id($table->[$i+1]->[0]) if ($i + 1 < @$table);
        } elsif ($this_dnafrag_strand == -1) {
          $node->right_node_id($table->[$i-1]->[0]) if ($i > 0);
          $node->left_node_id($table->[$i+1]->[0]) if ($i + 1 < @$table);
        }
        last;
      }
    }
  } else {
    ## Use the first GenomicAlign to set the LEFT NODE
    for (my $i = 0; $i < @$table; $i++) {
      my ($this_group_id, $this_dnafrag_start, $this_dnafrag_end, $this_dnafrag_strand) = @{$table->[$i]};
      if ($this_dnafrag_start == $dnafrag_start and $this_dnafrag_end == $dnafrag_end) {
        ## $table->[$i] correspond to the query node
        if ($this_dnafrag_strand == 1) {
          $node->left_node_id($table->[$i-1]->[0]) if ($i > 0);
        } elsif ($this_dnafrag_strand == -1) {
          $node->left_node_id($table->[$i+1]->[0]) if ($i + 1 < @$table);
        }
        last;
      }
    }

    ## Use the last GenomicAlign to set the RIGHT NODE
    $genomic_align = $genomic_aligns->[-1];
    $dnafrag_start = $genomic_align->dnafrag_start;
    $dnafrag_end = $genomic_align->dnafrag_end;

    $sth->execute(
        $genomic_align->dnafrag_id,
        $genomic_align->method_link_species_set_id,
        $dnafrag_end + $flanking,
        $dnafrag_start - $flanking - $genomic_align->method_link_species_set->max_alignment_length,
        $dnafrag_start - $flanking,
        );
    $table = $sth->fetchall_arrayref;
    for (my $i = 0; $i < @$table; $i++) {
      my ($this_group_id, $this_dnafrag_start, $this_dnafrag_end, $this_dnafrag_strand) = @{$table->[$i]};
      if ($this_dnafrag_start == $dnafrag_start and $this_dnafrag_end == $dnafrag_end) {
        ## $table->[$i] correspond to the query node
        if ($this_dnafrag_strand == 1) {
          $node->right_node_id($table->[$i+1]->[0]) if ($i + 1 < @$table);
        } elsif ($this_dnafrag_strand == -1) {
          $node->right_node_id($table->[$i-1]->[0]) if ($i > 0);
        }
        last;
      }
    }
  }
  $sth->finish;

  # Store this in the DB
  if ($node->left_node_id or $node->right_node_id) {
    $self->update_neighbourhood_data($node);
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
          'gag.group_id',
          'gag.type',
          'ga.genomic_align_id',
          'ga.genomic_align_block_id',
          'ga.method_link_species_set_id',
          'ga.dnafrag_id',
          'ga.dnafrag_start',
          'ga.dnafrag_end',
          'ga.dnafrag_strand',
          'ga.cigar_line',
          'ga.level_id',
          ];
}

sub tables {
  my $self = shift;
  return [
      ['genomic_align_tree', 'gat'],
      ['genomic_align_group', 'gag'],
      ['genomic_align', 'ga'],
      ];
}

sub left_join_clause {
  return "";
}

sub default_where_clause {
  return "gat.node_id = gag.group_id AND gag.genomic_align_id = ga.genomic_align_id";
}

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my $node_list = [];
  my $genomic_align_groups = {};
  my $genomic_aligns = {};
  while(my $rowhash = $sth->fetchrow_hashref) {
    my $genomic_align_group = $genomic_align_groups->{$rowhash->{group_id}};
    if (!defined($genomic_align_group)) {
      ## This is a new node
      my $node = $self->create_instance_from_rowhash($rowhash);
      $genomic_align_group = $node->genomic_align_group;
      $genomic_align_groups->{$rowhash->{group_id}} = $genomic_align_group;
      push @$node_list, $node;
    }
    if (!defined($genomic_aligns->{$rowhash->{genomic_align_id}})) {
      my $genomic_align = $self->_create_GenomicAlign_object_from_rowhash($rowhash);
      $genomic_align_group->add_GenomicAlign($genomic_align);
      $genomic_aligns->{$rowhash->{genomic_align_id}} = 1;
    }
  }

  return $node_list;
}

sub create_instance_from_rowhash {
  my $self = shift;
  my $rowhash = shift;

  my $node = new Bio::EnsEMBL::Compara::GenomicAlignTree;

  $self->init_instance_from_rowhash($node, $rowhash);
  my $genomic_align_group = $self->_create_GenomicAlignGroup_object_from_rowhash($rowhash);
  $node->genomic_align_group($genomic_align_group);

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


sub _create_GenomicAlignGroup_object_from_rowhash {
  my ($self, $rowhash) = @_;

  my $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup;
  $genomic_align_group->dbID($rowhash->{group_id});
  $genomic_align_group->adaptor($self->db->get_GenomicAlignGroupAdaptor);
  $genomic_align_group->type($rowhash->{type});

  return $genomic_align_group;
}


sub _create_GenomicAlign_object_from_rowhash {
  my ($self, $rowhash) = @_;

  my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign;
  $genomic_align->dbID($rowhash->{genomic_align_id});
  $genomic_align->adaptor($self->db->get_GenomicAlignAdaptor);
  $genomic_align->genomic_align_block_id($rowhash->{genomic_align_block_id});
  $genomic_align->method_link_species_set_id($rowhash->{method_link_species_set_id});
  $genomic_align->dnafrag_id($rowhash->{dnafrag_id});
  $genomic_align->dnafrag_start($rowhash->{dnafrag_start});
  $genomic_align->dnafrag_end($rowhash->{dnafrag_end});
  $genomic_align->dnafrag_strand($rowhash->{dnafrag_strand});
  $genomic_align->cigar_line($rowhash->{cigar_line});
  $genomic_align->level_id($rowhash->{level_id});

  return $genomic_align;
}

1;
