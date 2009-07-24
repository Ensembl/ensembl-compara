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

=head2 fetch_all_by_MethodLinkSpeciesSet
  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : integer $limit_number [optional]
  Arg  3     : integer $limit_index_start [optional]
  Example    : my $genomic_align_trees =
                  $genomic_align_tree_adaptor->
                      fetch_all_by_MethodLinkSpeciesSet($mlss);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignTree objects. Objects 
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignTree objects.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignTree object can be retrieved
  Caller     : none
  Status     : At risk

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

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Arg  3     : integer $start [optional, default = 1]
  Arg  4     : integer $end [optional, default = dnafrag_length]
  Arg  5     : integer $limit_number [optional, default = no limit]
  Arg  6     : integer $limit_index_start [optional, default = 0]
  Arg  7     : boolean $restrict_resulting_blocks [optional, default = no restriction]
  Example    : my $genomic_align_trees =
                  $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
                      $mlss, $dnafrag, 50000000, 50250000);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignTree objects. 
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignTree objects. Only dbID,
               adaptor and method_link_species_set are actually stored in the objects. The remaining
               attributes are only retrieved when requiered.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignTree object can be retrieved
  Caller     : none
  Status     : At risk

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

  if (defined($start) and defined($end) and $restrict) {
    my $restricted_genomic_align_trees = [];
    foreach my $this_genomic_align_tree (@$genomic_align_trees) {
      $this_genomic_align_tree = $this_genomic_align_tree->restrict_between_reference_positions(
          $start, $end, undef, "skip_empty_genomic_aligns");
      if (@{$this_genomic_align_tree->get_all_leaves()} > 1) {
        push(@$restricted_genomic_align_trees, $this_genomic_align_tree);
      }
    }
    $genomic_align_trees = $restricted_genomic_align_trees;
  }

  return $genomic_align_trees;
}


=head2 fetch_all_by_MethodLinkSpeciesSet_Slice

  Arg  1     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg  2     : Bio::EnsEMBL::Slice $original_slice
  Arg  3     : integer $limit_number [optional]
  Arg  4     : integer $limit_index_start [optional]
  Arg  5     : boolean $restrict_resulting_blocks [optional]
  Example    : my $genomic_align_trees =
                  $genomic_align_tree_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
                      $method_link_species_set, $original_slice);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignTree objects. The alignments may be
               reverse-complemented in order to match the strand of the original slice.
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignTree objects. Only dbID,
               adaptor and method_link_species_set are actually stored in the objects. The remaining
               attributes are only retrieved when required.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignTree object can be retrieved
  Caller     : $object->method_name
  Status     : At risk

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

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlignBlock $genomic_align_block
  Example    : my $genomic_align_tree =
                  $genomic_align_tree_adaptor->fetch_by_GenomicAlignBlock($gab_id);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignTree object. 
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignTree object. 
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignTree object can be retrieved
  Caller     : $object->method_name
  Status     : At risk

=cut

sub fetch_by_GenomicAlignBlock {
  my ($self, $genomic_align_block) = @_;

  my $genomic_align_block_id = $genomic_align_block->dbID;
  return undef unless $genomic_align_block_id;

#  my $join = [
#      [["genomic_align_tree","gat2"], "gat2.root_id = gat.node_id", undef],
#      [["genomic_align_group","gag2"], "gag2.group_id = gat2.node_id", undef],
#      [["genomic_align","ga2"], "ga2.genomic_align_id = gag2.genomic_align_id", undef],
#    ];
#  my $constraint = "WHERE ga2.genomic_align_block_id = $genomic_align_block_id";
#  my $genomic_align_trees = $self->_generic_fetch($constraint, $join);

  my $sql = "SELECT root_id FROM genomic_align
    LEFT JOIN genomic_align_group USING (genomic_align_id)
    LEFT JOIN genomic_align_tree ON (group_id = node_id)
    WHERE genomic_align_block_id = $genomic_align_block_id";

  my $sth = $self->prepare($sql);
  $sth->execute;
  my ($root_id) = $sth->fetchrow_array();
  $sth->finish();

  #print "root_id $root_id\n";

  #whole tree
  $sql = "SELECT " . join(",", @{$self->columns}) .  
    " FROM genomic_align_tree gat". " LEFT JOIN genomic_align_group gag ON (gat.node_id = gag.group_id) LEFT JOIN genomic_align ga ON (gag.genomic_align_id = ga.genomic_align_id) WHERE gat.root_id = $root_id";

  #root only
  #$sql = "SELECT " . join(",", @{$self->columns}) .
  #  " FROM genomic_align_tree gat LEFT JOIN genomic_align_group gag ON (gat.node_id = gag.group_id) LEFT JOIN genomic_align ga ON (gag.genomic_align_id = ga.genomic_align_id) WHERE gat.node_id = $root_id";

  $sth = $self->prepare($sql);
  $sth->execute;
  my $genomic_align_trees = $self->_objs_from_sth($sth);
  $sth->finish;

  my $root = $self->_build_tree_from_nodes($genomic_align_trees);

  $genomic_align_trees = [$root];

 #my $constraint = "WHERE gat.node_id = $root_id";
 # my $genomic_align_trees = $self->_generic_fetch($constraint);

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
                at this point. This may be useful for production
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
  Status      : At risk

=cut

sub store {
  my ($self, $node, $skip_left_right_indexes) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::GenomicAlignTree')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::GenomicAlignTree] not a $node");
  }

  ## Check the tree
   foreach my $this_node (@{$node->get_all_nodes}) {
#     throw "[$this_node] has no GenomicAlignGroup" if (!$this_node->genomic_align_group);
#     throw "[$this_node] has no GenomicAligns" if (!$this_node->get_all_GenomicAligns);
     throw "[$this_node] does not belong to this tree" if ($this_node->root ne $node);
   }

  my $leaves = $node->get_all_leaves;
  my $method_link_species_set = $leaves->[0]->get_all_GenomicAligns->[0]->method_link_species_set;


  ## Create and store all the GenomicAlignBlock objects (this stores the GenomicAlign objects as well)
  my $genomic_align_block_adaptor = $self->db->get_GenomicAlignBlockAdaptor();
  my $ancestral_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
      -method_link_species_set => $method_link_species_set,
      -group_id => $node->group_id);
  my $modern_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
      -method_link_species_set => $method_link_species_set,
      -group_id => $node->group_id);
  foreach my $genomic_align_node (@{$node->get_all_nodes}) {
    if ($genomic_align_node->is_leaf()) {
      foreach my $this_genomic_align (@{$genomic_align_node->get_all_GenomicAligns}) {
        $modern_genomic_align_block->add_GenomicAlign($this_genomic_align);
      }
    } elsif ($genomic_align_node->genomic_align_group) {
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

  ## Store this node and, recursively, all the sub nodes
  $self->store_node($node);

  ## Set and store the left and right indexes unless otherwise stated
  if (!$skip_left_right_indexes) {
      $self->sync_tree_leftright_index($node);
      $self->update_subtree($node);
  }

  return $node->node_id;
}


=head2 store_group

  Arg  1     : reference to Bio::EnsEMBL::Compara::GenomicAlignTree
  Example    : $genomic_align_tree_adaptor->store_group($genomic_align_tree);
  Description: Method for storing the group_id for a genomic_align_tree. The
               group_id is set as the genomic_align_block_id of the first
               genomic_align object
  Returntype : none
  Exceptions : - cannot lock tables
               - cannot update GenomicAlignBlock object
  Caller     : none
  Status     : At risk

=cut

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

=head2 store_node

  Arg  1     : reference to Bio::EnsEMBL::Compara::GenomicAlignTree
  Example    : $genomic_align_tree_adaptor->store_node($genomic_align_tree);
  Description: Method for storing a single node. Called recursively.
  Returntype : none
  Exceptions : throw if no genomic_align_group ID has been set
  Caller     : none
  Status     : At risk

=cut

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

  my $sth = $self->prepare("INSERT INTO genomic_align_tree 
                             (node_id,
                              parent_id,
                              root_id,
                              left_index,
                              right_index,
                              distance_to_parent)  VALUES (?,?,?,?,?,?)");
  $sth->execute("NULL", $parent_id, $root_id, $node->left_index, $node->right_index, $node->distance_to_parent);
  #print STDERR "LAST ID: ", $sth->{'mysql_insertid'}, "\n";
  $node->node_id($sth->{'mysql_insertid'});
  $sth->finish;

  #set root_id to be node_id for the root node.
  if ($root_id == 0) {
      my $sql = "UPDATE genomic_align_tree SET root_id = node_id WHERE node_id=?";
      my $sth = $self->prepare($sql);
      $sth->execute($node->node_id);
      $sth->finish;
  }

  $node->adaptor($self);

  if ($node->genomic_align_group) {
    my $genomic_align_group_adaptor = $self->db->get_GenomicAlignGroupAdaptor();
    $node->genomic_align_group->dbID($node->node_id);
    $genomic_align_group_adaptor->store($node->genomic_align_group);

    if (!$node->genomic_align_group or !$node->genomic_align_group->dbID) {
      throw("Cannot store before setting the genomic_align_group ID");
    }
    #print STDERR "NODE ", $node->node_id, " ", $node->name, " -- GROUP: ",
    #  $node->genomic_align_group->dbID, "\n";
  } else {
    #print STDERR "NODE ", $node->node_id, " ", $node->name, " -- NO GROUP\n";
  }


  foreach my $this_child (@{$node->children}) {
    $self->store_node($this_child);
  }

  return $node->node_id;
}

=head2 fetch_node_by_node_id

  Arg  1     : $node_id
  Example    : my $node = $self->adaptor->fetch_node_by_node_id($node_id);
  Description: Over-ride NestedSetAdaptor method for getting a node from its id
  Returntype : reference to Bio::EnsEMBL::Compara::GenomicAlignTree
  Exceptions : throw if not Bio::EnsEMBL::Compara::NestedSet
  Caller     : 
  Status     : At risk

=cut

sub fetch_node_by_node_id {
  my ($self, $node_id) = @_;

  #my $table= $self->tables->[0]->[1];
  #my $constraint = "WHERE $table.node_id = $node_id";
  #my ($node) = @{$self->_generic_fetch($constraint)};

  my $sql = "SELECT " . join(",", @{$self->columns}) .  
     " FROM genomic_align_tree gat". " LEFT JOIN genomic_align_group gag ON (gat.node_id = gag.group_id) LEFT JOIN genomic_align ga ON (gag.genomic_align_id = ga.genomic_align_id) WHERE gat.node_id = " . $node_id;

   my $sth = $self->prepare($sql);
   $sth->execute;
   my ($node) = @{$self->_objs_from_sth($sth)};
   $sth->finish;

  return $node;
}

=head2 fetch_parent_for_node

  Arg  1     : reference to Bio::EnsEMBL::Compara::GenomicAlignTree
  Example    : my $parent = $self->adaptor->fetch_parent_for_node($self);
  Description: Over-ride NestedSetAdaptor method for getting the parent of a node
  Returntype : reference to Bio::EnsEMBL::Compara::GenomicAlignTree
  Exceptions : throw if not Bio::EnsEMBL::Compara::NestedSet
  Caller     : 
  Status     : At risk

=cut

 sub fetch_parent_for_node {
   my ($self, $node) = @_;

   unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
     throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
   }

   #my $table= $self->tables->[0]->[1];
   #my $constraint = "WHERE $table.node_id = " . $node->_parent_id;
   #my ($parent) = @{$self->_generic_fetch($constraint)};

   my $sql = "SELECT " . join(",", @{$self->columns}) .  
     " FROM genomic_align_tree gat". " LEFT JOIN genomic_align_group gag ON (gat.node_id = gag.group_id) LEFT JOIN genomic_align ga ON (gag.genomic_align_id = ga.genomic_align_id) WHERE gat.node_id = " . $node->_parent_id;

   my $sth = $self->prepare($sql);
   $sth->execute;
   my ($parent) = @{$self->_objs_from_sth($sth)};
   $sth->finish;

   return $parent;
 }

=head2 fetch_all_children_for_node

  Arg  1     : reference to Bio::EnsEMBL::Compara::GenomicAlignTree
  Example    : my $node = $self->adaptor->fetch_all_children_for_node($self);
  Description: Over-ride NestedSetAdaptor method for getting the all the children of a node
  Returntype : reference to Bio::EnsEMBL::Compara::GenomicAlignTree
  Exceptions : throw if not Bio::EnsEMBL::Compara::NestedSet
  Caller     : 
  Status     : At risk

=cut

sub fetch_all_children_for_node {
  my ($self, $node) = @_;

  unless($node->isa('Bio::EnsEMBL::Compara::NestedSet')) {
    throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
  }

  my $sql = "SELECT " . join(",", @{$self->columns}) .  
     " FROM genomic_align_tree gat". " LEFT JOIN genomic_align_group gag ON (gat.node_id = gag.group_id) LEFT JOIN genomic_align ga ON (gag.genomic_align_id = ga.genomic_align_id) WHERE gat.parent_id = " . $node->node_id;

   my $sth = $self->prepare($sql);
   $sth->execute;
   my $kids = $self->_objs_from_sth($sth);
   $sth->finish;

  foreach my $child (@{$kids}) { $node->add_child($child); }

  return $node;
}

=head2 fetch_root_by_node

  Arg  1     : reference to Bio::EnsEMBL::Compara::GenomicAlignTree
  Example    : my $root = $self->adaptor->fetch_root_by_node($self);
  Description: Over-ride NestedSetAdaptor method for getting the root of a node
  Returntype : reference to Bio::EnsEMBL::Compara::GenomicAlignTree
  Exceptions : throw if not Bio::EnsEMBL::Compara::NestedSet
  Caller     : 
  Status     : At risk

=cut

 sub fetch_root_by_node {
   my ($self, $node) = @_;

   unless(UNIVERSAL::isa($node, 'Bio::EnsEMBL::Compara::NestedSet')) {
     throw("set arg must be a [Bio::EnsEMBL::Compara::NestedSet] not a $node");
   }

   my $alias = $self->tables->[0]->[1];

   my $left_index = $node->left_index;
   my $right_index = $node->right_index;

#   my $constraint = "WHERE $alias.left_index <= $left_index AND $alias.right_index >= $right_index";


#   my $nodes = $self->_generic_fetch($constraint);


   my $sql = "SELECT " . join(",", @{$self->columns}) .  
     " FROM genomic_align_tree gat". " LEFT JOIN genomic_align_group gag ON (gat.node_id = gag.group_id) LEFT JOIN genomic_align ga ON (gag.genomic_align_id = ga.genomic_align_id) WHERE gat.left_index <= $left_index AND gat.right_index >= $right_index";

   my $sth = $self->prepare($sql);
   $sth->execute;
   my $nodes = $self->_objs_from_sth($sth);
   $sth->finish;

   my $root = $self->_build_tree_from_nodes($nodes);

   return $root;
}




=head2 delete

  Arg  1     : reference to Bio::EnsEMBL::Compara::GenomicAlignTree
  Example    : $genomic_align_tree_adaptor->delete($root);
  Description: Method for deleting a Bio::EnsEMBL::Compara::GenomicAlignTree
               from a database. Must give the root ie does not delete
               sub-trees.
  Returntype : none
  Exceptions : none
  Caller     : none
  Status     : At risk

=cut

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


=head2 update_neighbourhood_data

  Arg  1     : reference to Bio::EnsEMBL::Compara::GenomicAlignTree
  Arg  2     : boolean $no_recursivity
  Example    : $self->update_neighbourhood_data($node);
  Description: Update the left and right node_ids of a genomic_align_tree
               table in a database
  Returntype : none
  Exceptions : none
  Caller     : none
  Status     : At risk

=cut

sub update_neighbourhood_data {
  my ($self, $node, $no_recursivity) = @_;

  my $sth = $self->prepare("UPDATE genomic_align_tree
      SET left_node_id = ?, right_node_id = ?
      WHERE node_id = ?");
  #print "update_neighbourhood_data " . $node->left_node_id . " "  .$node->right_node_id . " " . $node->node_id . "\n";
  $sth->execute($node->left_node_id, $node->right_node_id, $node->node_id);

  if (!$no_recursivity) {
    foreach my $this_children (@{$node->children}) {
      $self->update_neighbourhood_data($this_children);
    }
  }

  return $node;
}


=head2 set_neighbour_nodes_for_leaf

  Arg  1     : reference to Bio::EnsEMBL::Compara::GenomicAlignTree
  Arg  2     : int $flanking
  Example    : $self->update_neighbourhood_data($node);
  Description: Update the left and right node_ids of a genomic_align_tree
               table in a database
  Returntype : none
  Exceptions : none
  Caller     : none
  Status     : At risk

=cut

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

=head2 columns

  Args       : none
  Example    : $columns = $self->columns()
  Description: a list of [tablename, alias] pairs for use with generic_fetch
  Returntype : list of [tablename, alias] pairs
  Exceptions : none
  Caller     : NestedSetAdaptor::generic_fetch
  Status     : At risk

=cut

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

=head2 tables

  Args       : none
  Example    : $tables = $self->_tables()
  Description: a list of [tablename, alias] pairs for use with generic_fetch
  Returntype : list of [tablename, alias] pairs
  Exceptions : none
  Caller     : NestedSetAdaptor::generic_fetch
  Status     : At risk

=cut

sub tables {
  my $self = shift;
  return [
      ['genomic_align_tree', 'gat'],
      ['genomic_align_group', 'gag'],
      ['genomic_align', 'ga'],
      ];
}

=head2 left_join_clause

  Args       : none
  Example    : none
  Description: a left join clause for use with generic_fetch
  Returntype : none
  Exceptions : none
  Caller     : NestedSetAdaptor::generic_fetch
  Status     : At risk

=cut

sub left_join_clause {
#  return "LEFT JOIN genomic_align_group gag ON (gat.node_id = gag.group_id)".
#      " LEFT JOIN genomic_align ga ON (gag.genomic_align_id = ga.genomic_align_id)";
  return "";
}

=head2 default_where_clause

  Args       : none
  Example    : none
  Description: a where clause for use with generic_fetch
  Returntype : none
  Exceptions : none
  Caller     : NestedSetAdaptor::generic_fetch
  Status     : At risk

=cut

sub default_where_clause {
  return "gat.node_id = gag.group_id AND gag.genomic_align_id = ga.genomic_align_id";
#  return "";
}

=head2 _objs_from_sth

  Args[1]    : DBI::row_hashref $hashref containing key-value pairs
  Example    :   my $genomic_align_trees = $self->_objs_from_sth($sth);
  Description: convert DBI row hash reference into a 
               Bio::EnsEMBL::Compara::GenomicAlignTreeAdaptor object
  Returntype : listref of Bio::EnsEMBL::Compara::GenomicAlignTree objects
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my $node_list = [];
  my $genomic_align_groups = {};
  my $genomic_aligns = {};
  while(my $rowhash = $sth->fetchrow_hashref) {
    if (!defined($rowhash->{group_id})) {
       my $node = $self->create_instance_from_rowhash($rowhash);
       push @$node_list, $node;
    } else {
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
  }
  return $node_list;
}

=head2 create_instance_from_rowhash

  Args[1]    : DBI::row_hashref $hashref containing key-value pairs
  Example    : my $node = $self->create_instance_from_rowhash($rowhash);
  Description: convert DBI row hash reference into a 
               Bio::EnsEMBL::Compara::GenomicAlignTree object
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignTree object
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub create_instance_from_rowhash {
  my $self = shift;
  my $rowhash = shift;

  my $node = new Bio::EnsEMBL::Compara::GenomicAlignTree;

  $self->init_instance_from_rowhash($node, $rowhash);
  my $genomic_align_group = $self->_create_GenomicAlignGroup_object_from_rowhash($rowhash);
  $node->genomic_align_group($genomic_align_group) if ($genomic_align_group);

  return $node;
}

=head2 init_instance_from_rowhash

  Args[1]    : Bio::EnsEMBL::Compara::GenomicAlignTree object
  Args[2]    : DBI::row_hashref $hashref containing key-value pairs
  Example    : $self->init_instance_from_rowhash($node, $rowhash);
  Description: convert DBI row hash reference into a 
               Bio::EnsEMBL::Compara::GenomicAlignTree object
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignTree object
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

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


=head2 _create_GenomicAlignGroup_object_from_rowhash

  Args[1]    : DBI::row_hashref $hashref containing key-value pairs
  Example    :  my $genomic_align_group = $self->_create_GenomicAlignGroup_object_from_rowhash($rowhash);
  Description: convert DBI row hash reference into a 
               Bio::EnsEMBL::Compara::GenomicAlignGroup object
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignGroup object
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

sub _create_GenomicAlignGroup_object_from_rowhash {
  my ($self, $rowhash) = @_;

  return undef if (!$rowhash->{group_id});

  my $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup;
  $genomic_align_group->dbID($rowhash->{group_id});
  $genomic_align_group->adaptor($self->db->get_GenomicAlignGroupAdaptor);
  $genomic_align_group->type($rowhash->{type});

  return $genomic_align_group;
}

=head2 _create_GenomicAlign_object_from_rowhash

  Args[1]    : DBI::row_hashref $hashref containing key-value pairs
  Example    : my $genomic_align = $self->_create_GenomicAlign_object_from_rowhash($rowhash);
  Description: convert DBI row hash reference into a 
               Bio::EnsEMBL::Compara::GenomicAlign object
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : none
  Caller     : general
  Status     : At risk

=cut

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
