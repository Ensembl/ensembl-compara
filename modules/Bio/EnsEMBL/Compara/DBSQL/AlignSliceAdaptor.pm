=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor

=head1 DESCRIPTION

An AlignSlice can be used to map genes from one species onto another one. This
adaptor is used to fetch all the data needed for an AlignSlice from the database.

=head1 SYNOPSIS

  use Bio::EnsEMBL::Registry;

  ## Load adaptors using the Registry
  Bio::EnsEMBL::Registry->load_all();

  ## Fetch the query slice
  my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
          "Homo sapiens", "core", "Slice");
  my $query_slice = $query_slice_adaptor->fetch_by_region(
          "chromosome", "14", 50000001, 50010001);

  ## Fetch the method_link_species_set
  my $mlss_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
          "Compara26", "compara", "MethodLinkSpeciesSet");
  my $method_link_species_set = $mlss_adaptor->fetch_by_method_link_type_registry_aliases(
          "LASTZ_NET", ["Homo sapiens", "Rattus norvegicus"]);

  ## Fetch the align_slice
  my $align_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
          "Compara26",
          "compara",
          "AlignSlice"
      );
  my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
          $query_slice,
          $method_link_species_set,
          "expanded"
      );

=cut


package Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor;

use strict;
use warnings;
no warnings qw(uninitialized);

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);
use Bio::EnsEMBL::Compara::AlignSlice;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 fetch_by_Slice_MethodLinkSpeciesSet

  Arg[1]     : Bio::EnsEMBL::Slice $query_slice
  Arg[2]     : Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Arg[3]     : [optional] boolean $expanded (def. FALSE)
  Arg[4]     : [optional] boolean $solve_overlapping (def. FALSE)
  Arg[5]     : [optional] Bio::EnsEMBL::Slice $target_slice
  Example    :
      my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
              $query_slice, $method_link_species_set);
  Description: Fetches from the database all the data needed for the AlignSlice
               corresponding to the $query_slice and the given
               $method_link_species_set. Setting $expanded to anything different
               from 0 or "" will create an AlignSlice in "expanded" mode. This means
               that gaps are allowed in the reference species in order to allocate
               insertions from other species.
               By default overlapping alignments are ignored. You can choose to
               reconciliate the alignments by means of a fake alignment setting the
               solve_overlapping option to TRUE.
               In order to restrict the AlignSlice to alignments with a given
               genomic region, you can specify a target_slice. All alignments which
               do not match this slice will be ignored.
  Returntype : Bio::EnsEMBL::Compara::AlignSlice
  Exceptions : thrown if wrong arguments are given

=cut

sub fetch_by_Slice_MethodLinkSpeciesSet {
  my ($self, $reference_slice, $method_link_species_set, $expanded, $solve_overlapping, $target_slice) = @_;

  assert_ref($reference_slice, 'Bio::EnsEMBL::Slice', 'reference_slice');
  assert_ref($method_link_species_set, 'Bio::EnsEMBL::Compara::MethodLinkSpeciesSet', 'method_link_species_set');

  # Use cache whenever possible
  my $solve_overlapping_detail;
  if ($solve_overlapping && $solve_overlapping eq "restrict") {
    $solve_overlapping_detail = "merge-overlaps";
  } elsif ($solve_overlapping) {
    $solve_overlapping_detail = "all-overlaps";
  } else {
    $solve_overlapping_detail = "no-overlaps";
  }
  my $key = $reference_slice->name.":".$method_link_species_set->dbID.":".($expanded?"exp":"cond").
      ":".$solve_overlapping_detail;

  if (defined($target_slice)) {
    assert_ref($target_slice, 'Bio::EnsEMBL::Slice', 'target_slice');
    $key .= ":".$target_slice->name();
  }
  return $self->{'_cache'}->{$key} if (defined($self->{'_cache'}->{$key}));

  my $genomic_align_block_adaptor = $self->db->get_GenomicAlignBlockAdaptor;
  my $genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
          $method_link_species_set,
          $reference_slice
      );

  ## Remove all alignments not matching the target slice if any
  if (defined($target_slice)) {
    ## Get the DnaFrag for the target Slice
    my $target_dnafrag = $self->db->get_DnaFragAdaptor->fetch_by_Slice($target_slice);
    if (!$target_dnafrag) {
      throw("Cannot get a DnaFrag for the target Slice");
    }

    ## Loop through all the alignment blocks and test whether they match the target slice or not
    for (my $i = 0; $i < @$genomic_align_blocks; $i++) {
      my $this_genomic_align_block = $genomic_align_blocks->[$i];
      my $hits_the_target_slice = 0;
      foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_non_reference_genomic_aligns}) {
        if ($this_genomic_align->dnafrag->dbID == $target_dnafrag->dbID and
            $this_genomic_align->dnafrag_start <= $target_slice->end and
            $this_genomic_align->dnafrag_end >= $target_slice->start) {
          $hits_the_target_slice = 1;
          last;
        }
      }
      if (!$hits_the_target_slice) {
        splice(@$genomic_align_blocks, $i, 1);
        $i--;
      }
    }
  }

  my $genomic_align_trees = ();
  my $species_order;

  #Get the species tree for PECAN or HAL alignments
  if ($method_link_species_set->method->class =~ /GenomicAlignBlock.multiple_alignment/ and  @$genomic_align_blocks) {
    my $first_genomic_align_block = $genomic_align_blocks->[0];
    my $genomic_align_tree = $first_genomic_align_block->get_GenomicAlignTree;
    
    #want to create species_order
    $species_order = _get_species_order($genomic_align_tree);
  } elsif ($method_link_species_set->method->class =~ /GenomicAlignTree/ and @$genomic_align_blocks) {
    my $genomic_align_tree_adaptor = $self->db->get_GenomicAlignTreeAdaptor;
    foreach my $this_genomic_align_block (@$genomic_align_blocks) {
      my $this_genomic_align_tree = $genomic_align_tree_adaptor->
          fetch_by_GenomicAlignBlock($this_genomic_align_block);
      push(@$genomic_align_trees, $this_genomic_align_tree);

    }
    my $last_node_id = undef;
    my $tree_order;
    foreach my $this_genomic_align_tree (@$genomic_align_trees) {
      if ($last_node_id) {
        $tree_order->{$this_genomic_align_tree->node_id}->{prev} = $last_node_id;
        $tree_order->{$last_node_id}->{next} = $this_genomic_align_tree;
      }
      $last_node_id = $this_genomic_align_tree->node_id;
    }

    ## First tree. Build the species order using the first tree only
    $species_order = _get_species_order($genomic_align_trees->[0]);

    $| = 1;
    ## Combine the first tree with the second, the resulting order with the third and so on
    foreach my $this_genomic_align_tree (@$genomic_align_trees) {
      my $next_genomic_align_tree = $tree_order->{$this_genomic_align_tree->node_id}->{next};
      next if (!$next_genomic_align_tree);
      _combine_genomic_align_trees($species_order, $next_genomic_align_tree);
    }
  }

  my $align_slice = new Bio::EnsEMBL::Compara::AlignSlice(
          -adaptor => $self,
          -reference_Slice => $reference_slice,
          -Genomic_Align_Blocks => $genomic_align_blocks,
          -Genomic_Align_Trees => $genomic_align_trees,
          -species_order => $species_order,
          -method_link_species_set => $method_link_species_set,
          -expanded => $expanded,
          -solve_overlapping => $solve_overlapping,
      );
  $self->{'_cache'}->{$key} = $align_slice;

  return $align_slice;
}


=head2 fetch_by_GenomicAlignBlock

  Arg[1]     : Bio::EnsEMBL::Compara::GenomicAlignBlock $genomic_align_block
  Arg[2]     : [optional] boolean $expanded (def. FALSE)
  Arg[3]     : [optional] boolean $solve_overlapping (def. FALSE)
  Example    :
      my $align_slice = $align_slice_adaptor->fetch_by_GenomicAlignBlock(
              $genomic_align_block);
  Description: Uses this genomic_aling_block to create an AlignSlice.
               Setting $expanded to anything different
               from 0 or "" will create an AlignSlice in "expanded" mode. This means
               that gaps are allowed in the reference species in order to allocate
               insertions from other species.
               By default overlapping alignments are ignored. You can choose to
               reconciliate the alignments by means of a fake alignment setting the
               solve_overlapping option to TRUE.
  Returntype : Bio::EnsEMBL::Compara::AlignSlice
  Exceptions : thrown if arg[1] is not a Bio::EnsEMBL::Compara::GenomicAlignBlock
  Exceptions : thrown if $genomic_align_block has no method_link_species_set

=cut

sub fetch_by_GenomicAlignBlock {
  my ($self, $genomic_align_block, $expanded, $solve_overlapping) = @_;

  assert_ref($genomic_align_block, 'Bio::EnsEMBL::Compara::GenomicAlignBlock', 'genomic_align_block');
  my $method_link_species_set = $genomic_align_block->method_link_species_set();
  throw("GenomicAlignBlock [$genomic_align_block] has no MethodLinkSpeciesSet")
      unless ($method_link_species_set);
  my $reference_genomic_align = $genomic_align_block->reference_genomic_align;
  if (!$reference_genomic_align) {
    $genomic_align_block->reference_genomic_align($genomic_align_block->get_all_GenomicAligns->[0]);
    $reference_genomic_align = $genomic_align_block->reference_genomic_align;
  }
  my $reference_slice = $reference_genomic_align->get_Slice();

  # Use cache whenever possible
  my $key;
  if ($genomic_align_block->dbID) {
    $key = "gab_".$genomic_align_block->dbID.":".($expanded?"exp":"cond").
        ":".($solve_overlapping?"fake-overlap":"non-overlap");
  } else {
    $key = "gab_".$genomic_align_block.":".($expanded?"exp":"cond").
        ":".($solve_overlapping?"fake-overlap":"non-overlap");
  }
  return $self->{'_cache'}->{$key} if (defined($self->{'_cache'}->{$key}));

  my $align_slice = new Bio::EnsEMBL::Compara::AlignSlice(
          -adaptor => $self,
          -reference_Slice => $reference_slice,
          -Genomic_Align_Blocks => [$genomic_align_block],
          -method_link_species_set => $method_link_species_set,
          -expanded => $expanded,
          -solve_overlapping => $solve_overlapping,
          -preserve_blocks => 1,
      );
  $self->{'_cache'}->{$key} = $align_slice;

  return $align_slice;
}


=head2 flush_cache

  Arg[1]     : none
  Example    : $align_slice_adaptor->flush_cache()
  Description: Destroy the cache
  Returntype : none
  Exceptions : none

=cut

sub flush_cache {
  my ($self) = @_;
  foreach my $align_slice (values (%{$self->{'_cache'}})) {
    $align_slice->DESTROY;
  }
  undef $self->{'_cache'};
}

=head2 _get_species_order

  Arg[1]     : Bio::EnsEMBL::Compara::GenomicAlignTree $genomic_align_tree
  Example    :
  Description: This method returns a sorted array of species to be used when creating a new Bio::EnsEMBL::Compara::AlignSlice object
  Returntype : array of hashes
  Exceptions : none

=cut

sub _get_species_order {
  my ($genomic_align_tree) = @_;
  
  my $species_order;
  foreach my $this_genomic_align_node (@{$genomic_align_tree->get_all_sorted_genomic_align_nodes}) {
    next if (!@{$this_genomic_align_node->get_all_genomic_aligns_for_node});
    my $this_genomic_align = $this_genomic_align_node->get_all_genomic_aligns_for_node->[0];
    my $genome_db = $this_genomic_align->genome_db;
    my $this_node_id = $this_genomic_align_node->node_id;
    my $right_node_id = _get_right_node_id($this_genomic_align_node);
    my $genomic_align_ids = [];
    foreach my $each_genomic_align (@{$this_genomic_align_node->get_all_genomic_aligns_for_node}) {
      push (@$genomic_align_ids, $each_genomic_align->dbID);
    }

    push(@$species_order,
	 {
	  genome_db => $genome_db,
	  right_node_id => $right_node_id,
	  genomic_align_ids => $genomic_align_ids,
	 });
  }
  return $species_order;
}

=head2 _combine_genomic_align_trees

  Arg[1]     : listref $species_order
  Arg[2]     : Bio::EnsEMBL::Compara::GenomicAlignTree $next_tree
  Description: This method tries to accommodate the nodes in $next_tree
               into $species_order. It uses several approaches. If there
               is information available about left and right node IDs, it
               will use it to link the nodes. Alternatively, it will rely
               on the species names to do its best. When a new species name
               appears in the $next_tree, it will try to insert it in the right
               position.
  Returntype : none
  Exceptions : none

=cut

sub _combine_genomic_align_trees {
  my ($species_order, $next_tree) = @_;

  my (%next_tree_node_ids, %existing_right_node_ids, %existing_species_names);

  foreach my $this_genomic_align_node (@{$next_tree->get_all_sorted_genomic_align_nodes}) {
    my $this_node_id = $this_genomic_align_node->node_id;
    $next_tree_node_ids{$this_node_id} = 1;
  }

  while (my ($index, $species_def) = each @$species_order) {
    my $right_node_id = $species_def->{right_node_id};
    $existing_right_node_ids{$right_node_id} = 1 if ($right_node_id);
    my $genome_db_name = $species_def->{genome_db}->name;
    $existing_species_names{$genome_db_name} = $index if ($genome_db_name ne "ancestral_sequences");
  }

  my $pending_ancestral_species;
  my $species_counter = 0;

  ## MAIN LOOP. For each node in $next_tree, try to find the best position in $species_order. First,
  ## rely on $right_node_id, then on the species name. If $next_tree has a new species name, include
  ## it in the right place, if possible, or append the node to the end of $species_order.
  foreach my $this_genomic_align_node (@{$next_tree->get_all_sorted_genomic_align_nodes}) {
    next if (!@{$this_genomic_align_node->get_all_genomic_aligns_for_node});
    my $this_genomic_align = $this_genomic_align_node->get_all_genomic_aligns_for_node->[0];
    my $this_genome_db = $this_genomic_align->genome_db;
    my $this_node_id = $this_genomic_align_node->node_id;
    my $this_right_node_id = _get_right_node_id($this_genomic_align_node);
    my $these_genomic_align_ids = [];
    foreach my $each_genomic_align (@{$this_genomic_align_node->get_all_genomic_aligns_for_node}) {
      push (@$these_genomic_align_ids, $each_genomic_align->dbID);
    }
    ## DEBUG info
    # print "Inserting ", $this_genome_db->name, " into the species_order\n";

    my $match = 0;
    ## SECONDARY LOOP. Note that the $species_counter is not reset at the end of the loop.
    ## This ensures that we do not add two nodes to $species_order and that we preserve as
    ## far as possible the order in all existing and in the new trees.
    while (!$match) {
      my $species = $species_order->[$species_counter];
      my ($species_genome_db, $species_right_node_id);
      $species_genome_db = $species->{genome_db} if defined $species;
      $species_right_node_id = $species->{right_node_id} if defined $species;
      $match = 1;

      ## 1. Use info from $species_right_node_id if available
      if (defined($species_right_node_id) and $species_right_node_id == $this_node_id) {
        $species_order->[$species_counter]->{right_node_id} = $this_right_node_id;
        push (@{$species_order->[$species_counter]->{genomic_align_ids}}, @$these_genomic_align_ids);
        if (defined $pending_ancestral_species) {
          my $prev_species_index = $species_counter - 1;
          $species_order->[$prev_species_index]->{right_node_id} = $pending_ancestral_species->{right_node_id};
          push @{$species_order->[$prev_species_index]->{genomic_align_ids}}, @{$pending_ancestral_species->{genomic_align_ids}};
          undef $pending_ancestral_species;
        }
        # _debug_info("NODE LINK", $species_order, $species_counter);

      ## 2. If there is no info about right node or this points to a node not found in next tree,
      ## rely on the species name
      } elsif (defined $species_genome_db and ($species_genome_db->name eq $this_genome_db->name)) {
        my $debug_msg = "MATCH";
        if ($this_genome_db->name eq "ancestral_sequences") {
          $pending_ancestral_species = {
            genome_db         => $this_genome_db,
            right_node_id     => $this_right_node_id,
            genomic_align_ids => [ @$these_genomic_align_ids ],
          };
          $debug_msg = "TENTATIVE " . $debug_msg;
        } else {
          $species_order->[$species_counter]->{right_node_id} = $this_right_node_id;
          push (@{$species_order->[$species_counter]->{genomic_align_ids}}, @$these_genomic_align_ids);
          if (defined $pending_ancestral_species) {
            my $prev_species_index = $species_counter - 1;
            $species_order->[$prev_species_index]->{right_node_id} = $pending_ancestral_species->{right_node_id};
            push @{$species_order->[$prev_species_index]->{genomic_align_ids}}, @{$pending_ancestral_species->{genomic_align_ids}};
            undef $pending_ancestral_species;
          }
        }
        # _debug_info($debug_msg, $species_order, $species_counter);

      ## 3. If the species is in $species_order but next tree has a different order, link the node
      ## information disregarding the next tree's species order
      } elsif (exists $existing_species_names{$this_genome_db->name}) {
        $species_counter = $existing_species_names{$this_genome_db->name};
        $species_order->[$species_counter]->{right_node_id} = $this_right_node_id;
        push (@{$species_order->[$species_counter]->{genomic_align_ids}}, @$these_genomic_align_ids);
        if (defined $pending_ancestral_species) {
          my $prev_species_index = $species_counter - 1;
          $species_order->[$prev_species_index]->{right_node_id} = $pending_ancestral_species->{right_node_id};
          push @{$species_order->[$prev_species_index]->{genomic_align_ids}}, @{$pending_ancestral_species->{genomic_align_ids}};
          undef $pending_ancestral_species;
        }
        # _debug_info("OUT-OF-ORDER NODE LINK", $species_order, $species_counter);

      ## 4. Insert/append this species if not found in $species_order
      } elsif ( (!exists $existing_right_node_ids{$this_node_id} and !exists $existing_species_names{$this_genome_db->name})
                || $species_counter >= scalar(@$species_order) ) {
        my $debug_msg = "APPEND";
        if ($this_genome_db->name eq "ancestral_sequences") {
          $pending_ancestral_species = {
            genome_db         => $this_genome_db,
            right_node_id     => $this_right_node_id,
            genomic_align_ids => [ @$these_genomic_align_ids ],
          };
          $debug_msg = "TENTATIVE " . $debug_msg;
        } else {
          $debug_msg = "INSERT" if ($species_counter < $#$species_order);
          if (defined $pending_ancestral_species) {
            splice(@$species_order, $species_counter - 1, 0, $pending_ancestral_species);
            undef $pending_ancestral_species;
          }
          splice(@$species_order, $species_counter, 0, {
            genome_db         => $this_genome_db,
            right_node_id     => $this_right_node_id,
            genomic_align_ids => [ @$these_genomic_align_ids ],
          });
          # Update the existing species names
          $existing_species_names{$this_genome_db->name} = $species_counter;
        }
        # _debug_info($debug_msg, $species_order, $species_counter);
      } else {
        $match = 0;
      }
      $species_counter++;
    }
    ## DEBUG info
    # print "[ENTER]";
    # <STDIN>;
  }

  return;
}

sub _get_right_node_id {
  my ($this_genomic_align_node) = @_;

  my $use_right = 1;
  $use_right = 1 - $use_right if (!$this_genomic_align_node->root->original_strand);

  my $neighbour_node;
  if ($use_right) {
    $neighbour_node = $this_genomic_align_node->right_node;
  } else {
    $neighbour_node = $this_genomic_align_node->left_node;
  }
  if ($neighbour_node) {
    return $neighbour_node->node_id;
  }

  return undef;
}


sub _debug_info {
    my ($msg, $species_order, $species_counter) = @_;

    print "$msg!\n";
    while (my ($i, $elem) = each @$species_order) {
        print $elem->{genome_db}->name, " [", join(',', @{$elem->{genomic_align_ids}}), "]",
            ($i == $species_counter) ? " ***" : "", "\n";
    }
}


1;
