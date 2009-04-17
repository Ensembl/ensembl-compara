#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor
#
# Cared for by Javier Herrero <jherrero@ebi.ac.uk>
#
# Copyright EnsEMBL Team
#
# You may distribute this module under the same terms as perl itself
#
# pod documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor - An AlignSlice can be used to map genes from one species onto another one. This adaptor is used to fetch all the data needed for an AlignSlice from the database.

=head1 INHERITANCE

This module inherits attributes and methods from Bio::EnsEMBL::DBSQL::BaseAdaptor

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
          "BLASTZ_NET", ["Homo sapiens", "Rattus norvegicus"]);

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

=head1 OBJECT ATTRIBUTES

=over

=item db (from SUPER class)

=back

=head1 AUTHORS

Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

Copyright (c) 2004. EnsEMBL Team

You may distribute this module under the same terms as perl itself

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...

package Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor;

use strict;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Bio::EnsEMBL::Compara::AlignSlice;

our @ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

=head2 new (CONSTRUCTOR)

  Arg        : 
  Example    : 
  Description: Creates a new AlignSliceAdaptor object
  Returntype : Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor
  Exceptions : none
  Caller     : Bio::EnsEMBL::Registry->get_adaptor

=cut

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  return $self;
}


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
  Caller     : $object->methodname

=cut

sub fetch_by_Slice_MethodLinkSpeciesSet {
  my ($self, $reference_slice, $method_link_species_set, $expanded, $solve_overlapping, $target_slice) = @_;

  throw("[$reference_slice] is not a Bio::EnsEMBL::Slice")
      unless ($reference_slice and ref($reference_slice) and
          $reference_slice->isa("Bio::EnsEMBL::Slice"));
  throw("[$method_link_species_set] is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet")
      unless ($method_link_species_set and ref($method_link_species_set) and
          $method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));

  # Use cache whenever possible
  my $key = $reference_slice->name.":".$method_link_species_set->dbID.":".($expanded?"exp":"cond").
      ":".($solve_overlapping?"fake-overlap":"non-overlap");
  if (defined($target_slice)) {
    throw("[$target_slice] is not a Bio::EnsEMBL::Slice")
        unless ($target_slice and ref($target_slice) and
            $target_slice->isa("Bio::EnsEMBL::Slice"));
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
  if ($method_link_species_set->method_link_class =~ /GenomicAlignTree/ and @$genomic_align_blocks) {
    my $genomic_align_tree_adaptor = $self->db->get_GenomicAlignTreeAdaptor;
    foreach my $this_genomic_align_block (@$genomic_align_blocks) {
#       print $this_genomic_align_block->reference_genomic_align, "\n";
      my $this_genomic_align_tree = $genomic_align_tree_adaptor->
          fetch_by_GenomicAlignBlock($this_genomic_align_block);
      push(@$genomic_align_trees, $this_genomic_align_tree);
#       $this_genomic_align_tree->print();
#       foreach my $this_ga (@{$this_genomic_align_tree->get_all_sorted_genomic_align_nodes}) {
#         print $this_ga->genomic_align->genome_db->name(), "\n";
#       }

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
    foreach my $this_genomic_align_node (@{$genomic_align_trees->[0]->get_all_sorted_genomic_align_nodes}) {
      next if (!@{$this_genomic_align_node->get_all_GenomicAligns});
      my $this_genomic_align = $this_genomic_align_node->get_all_GenomicAligns->[0];
      my $genome_db = $this_genomic_align->genome_db;
      my $this_node_id = $this_genomic_align_node->node_id;
      my $right_node_id = _get_right_node_id($this_genomic_align_node);
      my $genomic_align_ids = [];
      foreach my $each_genomic_align (@{$this_genomic_align_node->get_all_GenomicAligns}) {
        push (@$genomic_align_ids, $each_genomic_align->dbID);
      }
      push(@$species_order,
            {
            genome_db => $genome_db,
            right_node_id => $right_node_id,
            genomic_align_ids => $genomic_align_ids,
            # #               last_node => $this_genomic_align_node,
            });
    }
    $| = 1;
    ## Combine the first tree with the second, the resulting order with the third and so on
    foreach my $this_genomic_align_tree (@$genomic_align_trees) {
      my $next_genomic_align_tree = $tree_order->{$this_genomic_align_tree->node_id}->{next};
      next if (!$next_genomic_align_tree);
# # #       print STDERR "\nBEFORE:\n - ", join("\n - ", map {
# # #               $_->{genome_db}->name." (".($_->{right_node_id} or "***").")  [".
# # #               join(" : ", @{$_->{genomic_align_ids}})."]"
# # #           } @$species_order), "\n";
      _combine_genomic_align_trees($species_order, $this_genomic_align_tree, $next_genomic_align_tree);
#       $next_genomic_align_tree->print();
# # #       print STDERR "\nAFTER:\n - ", join("\n - ", map {
# # #               $_->{genome_db}->name." (".($_->{right_node_id} or "***").")  [".
# # #               join(" : ", @{$_->{genomic_align_ids}})."]"
# # #           } @$species_order), "\n";
# # #       <STDIN>;

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
  Caller     : $object->methodname

=cut

sub fetch_by_GenomicAlignBlock {
  my ($self, $genomic_align_block, $expanded, $solve_overlapping) = @_;

  throw("[$genomic_align_block] is not a Bio::EnsEMBL::Compara::GenomicAlignBlock")
      unless (UNIVERSAL::isa($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignBlock"));
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
  Caller     : $object->methodname

=cut

sub flush_cache {
  my ($self) = @_;
  foreach my $align_slice (values (%{$self->{'_cache'}})) {
    $align_slice->DESTROY;
  }
  undef $self->{'_cache'};
}


=head2 _combine_genomic_align_trees

  Arg[1]     : listref $species_order
  Arg[2]     : Bio::EnsEMBL::Compara::GenomicAlignTree $this_tree
  Arg[3]     : Bio::EnsEMBL::Compara::GenomicAlignTree $next_tree
  Example    :
  Description: This method tries to accommodate the nodes in $next_tree
               into $species_order. It uses several approaches. If there
               is information available about left and right node IDs, it
               will use it to link the nodes. Alternatively, it will rely
               on the species names to do its best. When a new species name
               appears in the $next_tree, it will try to insert it in the right
               position.
  Returntype : none
  Exceptions : none
  Caller     : $object->methodname

=cut

sub _combine_genomic_align_trees {
  my ($species_order, $this_tree, $next_tree) = @_;

  # $this_tree is already taken into account in the species_order. $next_tree is the new info to combine
  my $species_counter = 0;
  my $existing_node_ids; # Lists all node_ids in the next tree
  my $existing_right_node_ids;
  my $next_species_names; # Lists all species names in the next tree
  my $existing_species_names; # Lists all species names in the $species_order tracks

  ## Initialise values
  foreach my $this_genomic_align_node (@{$next_tree->get_all_sorted_genomic_align_nodes}) {
    my $this_node_id = $this_genomic_align_node->node_id;
    $existing_node_ids->{$this_node_id} = 1;
    push(@$next_species_names, $this_genomic_align_node->genomic_align_group->genome_db->name)
        if ($this_genomic_align_node->genomic_align_group and 
            $this_genomic_align_node->genomic_align_group->genome_db->name ne "Ancestral sequences");
  }
  foreach my $species_def (@$species_order) {
    my $right_node_id = $species_def->{right_node_id};
    $existing_right_node_ids->{$right_node_id} = 1 if ($right_node_id);
    push(@$existing_species_names, $species_def->{genome_db}->name);
  }

  ## MAIN LOOP. For each of the nodes in $next_tree, try to find the best position in $species_order.
  ## First, rely on the right_node_id, then on the species_name. If $next_tree has a new species_name,
  ## include it. If no good position has been found, append the node to the end of the $species_order.
  foreach my $this_genomic_align_node (@{$next_tree->get_all_sorted_genomic_align_nodes}) {
    next if (!@{$this_genomic_align_node->get_all_GenomicAligns});
    my $this_genomic_align = $this_genomic_align_node->get_all_GenomicAligns->[0];
    my $this_genome_db = $this_genomic_align->genome_db;
    my $this_node_id = $this_genomic_align_node->node_id;
    my $this_right_node_id = _get_right_node_id($this_genomic_align_node);
    my $these_genomic_align_ids = [];
    foreach my $each_genomic_align (@{$this_genomic_align_node->get_all_GenomicAligns}) {
      push (@$these_genomic_align_ids, $each_genomic_align->dbID);
    }
    ## DEBUG info
    # print "Inserting ", $this_genome_db->name, " into the species_order\n";

    my $match = 0;
    ## SECONDARY LOOP. Note that the $species_counter is not reset at the end of the loop.
    ## This ensures that we do not add two nodes to the same species_order track and that we
    ## preserve the order in all existing and in the new tree.
    while (!$match and $species_counter < @$species_order) {
      my $species_genome_db = $species_order->[$species_counter]->{genome_db};
      my $species_right_node_id = $species_order->[$species_counter]->{right_node_id};
      $match = 1;

      ## 1. Use info from species_right_node_id if available
      if (defined($species_right_node_id) and $species_right_node_id == $this_node_id) {
          $species_order->[$species_counter]->{right_node_id} = $this_right_node_id;
          # #         $species_order->[$species_counter]->{last_node} = $this_genomic_align_node;
        push (@{$species_order->[$species_counter]->{genomic_align_ids}}, @$these_genomic_align_ids);
        ## DEBUG info
        # print "NODE LINK!\n";
        # for (my $i = 0; $i<@$species_order; $i++) {
        #   if ($i == $species_counter) {
        #     print $species_order->[$i]->{genome_db}->name, "***\n";
        #   } else {
        #     print $species_order->[$i]->{genome_db}->name, "\n";
        #   }
        # }

      ## 2. Force insertions in a math to the next right_node is expected
      } elsif (defined($species_right_node_id) and exists($existing_node_ids->{$species_right_node_id})) {
        splice(@$species_order, $species_counter, 0, {
            genome_db => $this_genome_db,
            right_node_id => $this_right_node_id,
            genomic_align_ids => [@$these_genomic_align_ids],
          });
        ## DEBUG info
        # print "FORCE INSERT!\n";
        # for (my $i = 0; $i<@$species_order; $i++) {
        #   if ($i == $species_counter) {
        #     print $species_order->[$i]->{genome_db}->name, "***\n";
        #   } else {
        #     print $species_order->[$i]->{genome_db}->name, "\n";
        #   }
        # }

      ## 3. If there is no info about right node or this points to a node not found in next tree,
      ## rely on the species name
      } elsif ($this_genome_db->name eq $species_genome_db->name
                and (!defined($species_right_node_id) or
                    !defined($existing_node_ids->{$species_right_node_id}))
          ) {
        $species_order->[$species_counter]->{right_node_id} = $this_right_node_id;
        push (@{$species_order->[$species_counter]->{genomic_align_ids}}, @$these_genomic_align_ids);
        ## DEBUG info
        # print "MATCH!\n";
        # for (my $i = 0; $i<@$species_order; $i++) {
        #   if ($i == $species_counter) {
        #     print $species_order->[$i]->{genome_db}->name, "***\n";
        #   } else {
        #     print $species_order->[$i]->{genome_db}->name, "\n";
        #   }
        # }

      ## 4. Insert this species if not found in the remaining set of existing species (in species_order)
      } elsif (!defined($existing_right_node_ids->{$this_node_id})
          and !grep {$_ eq $this_genome_db->name} @$existing_species_names) {
        splice(@$species_order, $species_counter, 0, {
            genome_db => $this_genome_db,
            right_node_id => $this_right_node_id,
            genomic_align_ids => [@$these_genomic_align_ids],
          });
        ## DEBUG info
        # print "INSERT!\n";
        # for (my $i = 0; $i<@$species_order; $i++) {
        #   if ($i == $species_counter) {
        #     print $species_order->[$i]->{genome_db}->name, "***\n";
        #   } else {
        #     print $species_order->[$i]->{genome_db}->name, "\n";
        #   }
        # }

      ## Unset $match, try with the next $species_order track.
      } else {
        $match = 0;
      }
      $species_counter++;
      shift(@$existing_species_names);
    }

    ## 5. We have not found any good position for this node: add a new track to the $species_order
    if (!$match) {
      push(@$species_order, {
            genome_db => $this_genome_db,
            right_node_id => $this_right_node_id,
            genomic_align_ids => [@$these_genomic_align_ids],
        });
      $species_counter++;
      ## DEBUG info
      # print "APPEND!\n";
      # for (my $i = 0; $i<@$species_order; $i++) {
      #   if ($i == $species_counter) {
      #     print $species_order->[$i]->{genome_db}->name, "***\n";
      #   } else {
      #    print $species_order->[$i]->{genome_db}->name, "\n";
      #   }
      # }
    }
    ## DEBUG info
    # print "[ENTER]";
    # <STDIN>;
    shift(@$next_species_names);
  }

  return;
}

sub _get_right_node_id {
  my ($this_genomic_align_node) = @_;

  my $use_right = 1;
  $use_right = 1 - $use_right if (!$this_genomic_align_node->root->get_original_strand);

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


1;
