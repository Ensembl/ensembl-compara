package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree;

use strict;

use Data::Dumper;

use Bio::EnsEMBL::Utils::Scalar;
use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub store_genetree
{
    my $self = shift;
    my $tree = shift;

    printf("PHYML::store_genetree\n") if($self->debug);

    $tree->root->build_leftright_indexing(1);
    $self->compara_dba->get_GeneTreeAdaptor->store($tree);
    $self->compara_dba->get_GeneTreeNodeAdaptor->delete_nodes_not_in_tree($tree->root);

    if($self->debug >1) {
        print("done storing - now print\n");
        $tree->print_tree;
    }

    $self->store_node_tags($tree->root);
    $self->store_tree_tags($tree);

}

sub store_node_tags
{
    my $self = shift;
    my $node = shift;

    if (not $node->is_leaf) {
        my $node_type;
        if ($node->has_tag('node_type')) {
            $node_type = $node->get_tagvalue('node_type');
        } elsif ($node->get_tagvalue("DD", 0)) {
            $node_type = 'dubious';
        } elsif ($node->get_tagvalue('Duplication', '') eq '1') {
            $node_type = 'duplication';
        } else {
            $node_type = 'speciation';
        }
        $node->store_tag('node_type', $node_type);
        if ($self->debug) {
            print "store node_type: $node_type"; $node->print_node;
        }
    }

    if ($node->has_tag("E")) {
        my $n_lost = $node->get_tagvalue("E");
        $n_lost =~ s/.{2}//;        # get rid of the initial $-
        my @lost_taxa = split('-', $n_lost);
        foreach my $taxon (@lost_taxa) {
            if ($self->debug) {
                printf("store lost_taxon_id : $taxon "); $node->print_node;
            }
            $node->store_tag('lost_taxon_id', $taxon, 1);
        }
    }

    my %mapped_tags = ('B' => 'bootstrap', 'SIS' => 'species_intersection_score', 'T' => 'tree_support');
    foreach my $tag (keys %mapped_tags) {
        next unless $node->has_tag($tag);
        my $value = $node->get_tagvalue($tag);
        my $db_tag = $mapped_tags{$tag};
        # Because the duplication_confidence_score won't be computed for dubious nodes
        $db_tag = 'duplication_confidence_score' if ($node->get_tagvalue('node_type') eq 'dubious' and $tag eq 'SIS');
        # tree_support is only valid in protein trees (so far)
        next if ($tag eq 'T') and (not $self->param('store_tree_support'));

        $node->store_tag($db_tag, $value);
        if ($self->debug) {
            printf("store $tag as $db_tag: $value"); $node->print_node;
        }
    }

    foreach my $child (@{$node->children}) {
        $self->store_node_tags($child);
    }
}

sub parse_newick_into_tree {
  my $self = shift;
  my $newick_file = shift;
  my $tree = shift;
  
  #cleanup old tree structure- 
  #  flatten and reduce to only GeneTreeMember leaves
  $tree->root->flatten_tree;
  $tree->root->print_tree(20) if($self->debug);
  foreach my $node (@{$tree->root->get_all_leaves}) {
    next if($node->isa('Bio::EnsEMBL::Compara::GeneTreeMember'));
    $node->disavow_parent;
  }

  #parse newick into a new tree object structure
  my $newick = '';
  print("load from file $newick_file\n") if($self->debug);
  open (FH, $newick_file) or $self->throw("Couldnt open newick file [$newick_file]");
  while(<FH>) { $newick .= $_;  }
  close(FH);

  my $newroot = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick, "Bio::EnsEMBL::Compara::GeneTreeNode");
  $newroot->print_tree(20) if($self->debug > 1);

  my $split_genes = $self->param('split_genes');

  if (defined $split_genes) {
    print STDERR "Retrieved split_genes hash: ", Dumper($split_genes) if $self->debug;
    my $nsplits = 0;
    while ( my ($name, $other_name) = each(%{$split_genes})) {
        print STDERR "$name is split_gene of $other_name\n" if $self->debug;
        my $node = new Bio::EnsEMBL::Compara::GeneTreeNode;
        $node->name($name);
        my $othernode = $newroot->find_node_by_name($other_name);
        print STDERR "$node is split_gene of $othernode\n" if $self->debug;
        my $newnode = new Bio::EnsEMBL::Compara::GeneTreeNode;
        $nsplits++;
        $newnode->node_id(-$nsplits);
        $othernode->parent->add_child($newnode);
        $newnode->add_child($othernode);
        $newnode->add_child($node);
        $newnode->add_tag('node_type', 'gene_split');
        $newnode->print_tree(10);
    }
  }

  # get rid of the taxon_id needed by njtree -- name tag
  foreach my $leaf (@{$newroot->get_all_leaves}) {
    my $njtree_phyml_name = $leaf->get_tagvalue('name');
    $njtree_phyml_name =~ /(\d+)\_\d+/;
    my $member_id = $1;
    $leaf->add_tag('name', $member_id);
  }
  $newroot->print_tree(20) if($self->debug > 1);

  # Leaves of newick tree are named with member_id of members from
  # input tree move members (leaves) of input tree into newick tree to
  # mirror the 'member_id' nodes
  foreach my $member (@{$tree->root->get_all_leaves}) {
    my $tmpnode = $newroot->find_node_by_name($member->member_id);
    if($tmpnode) {
      $member->Bio::EnsEMBL::Compara::AlignedMember::copy($tmpnode);
      bless $tmpnode, 'Bio::EnsEMBL::Compara::GeneTreeMember';
      $tmpnode->node_id($member->node_id);
      $tmpnode->adaptor($member->adaptor);
    } else {
      print("unable to find node in newick for member");
      $member->print_member;
    }
  }

  foreach my $newsubroot (@{$newroot->children}) {
    $tree->root->add_child($newsubroot, $newsubroot->distance_to_parent);
  }

  # Newick tree is now empty so release it
  $newroot->release_tree;

  $tree->root->print_tree if($self->debug);
  # check here on the leaf to test if they all are GeneTreeMembers as
  # minimize_tree/minimize_node might not work properly
  foreach my $leaf (@{$tree->root->get_all_leaves}) {
    assert_ref($leaf, 'Bio::EnsEMBL::Compara::GeneTreeMember');
  }
}

sub store_tree_tags {
    my $self = shift;
    my $tree = shift;

    print "Storing Tree tags...\n";

    my @leaves = @{$tree->root->get_all_leaves};
    my @nodes = @{$tree->root->get_all_nodes};

    # Tree number of leaves.
    my $tree_num_leaves = scalar(@leaves);
    $tree->store_tag("tree_num_leaves",$tree_num_leaves);

    # Tree number of human peptides contained.
    my $num_hum_peps = 0;
    foreach my $leaf (@leaves) {
	$num_hum_peps++ if ($leaf->taxon_id == 9606);
    }
    $tree->store_tag("tree_num_human_peps",$num_hum_peps);

    # Tree max root-to-tip distance.
    my $tree_max_length = $tree->root->max_distance;
    $tree->store_tag("tree_max_length",$tree_max_length);

    # Tree max single branch length.
    my $tree_max_branch = 0;
    foreach my $node (@nodes) {
        my $dist = $node->distance_to_parent;
        $tree_max_branch = $dist if ($dist > $tree_max_branch);
    }
    $tree->store_tag("tree_max_branch",$tree_max_branch);

    # Tree number of duplications and speciations.
    my $num_dups = 0;
    my $num_specs = 0;
    foreach my $node (@nodes) {
        my $node_type = $node->get_tagvalue("node_type");
        if ((defined $node_type) and ($node_type ne 'speciation')) {
            $num_dups++;
        } else {
            $num_specs++;
        }
    }
    $tree->store_tag("tree_num_dup_nodes",$num_dups);
    $tree->store_tag("tree_num_spec_nodes",$num_specs);

    print "Done storing stuff!\n" if ($self->debug);
}


1;
