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

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree;

use strict;
use warnings;

use Data::Dumper;

use Bio::AlignIO;

use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


########################################
# Gene split mirroring code
#
# This will have the effect of grouping the different
# fragments of a gene split event together in a subtree
########################################
sub merge_split_genes {
    my ($self, $gene_tree) = @_;

    warn sprintf("%d leaves in the tree before merge_split_genes()\n", scalar(@{$gene_tree->get_all_leaves})) if $self->debug;
    my %leaf_by_seq_member_id = (map {$_->seq_member_id => $_} @{ $gene_tree->get_all_leaves });
    my $seq_type = $self->param('cdna') ? 'cds' : undef;
    my %split_genes;

    my $sth = $gene_tree->adaptor->db->dbc->prepare('SELECT DISTINCT gene_split_id FROM split_genes JOIN gene_tree_node USING (seq_member_id) WHERE root_id = ?');
    $sth->execute($gene_tree->root_id());
    my $gene_splits = $sth->fetchall_arrayref();
    $sth->finish;

    $sth = $gene_tree->adaptor->db->dbc->prepare('SELECT seq_member_id FROM split_genes JOIN gene_tree_node USING (seq_member_id) WHERE root_id = ? AND gene_split_id = ? ORDER BY seq_member_id');
    foreach my $gene_split (@$gene_splits) {
      $sth->execute($gene_tree->root_id(), $gene_split->[0]);
      my $partial_genes = $sth->fetchall_arrayref;
      my $seq_member_id1 = (shift @$partial_genes)->[0];
      my $protein1 = $leaf_by_seq_member_id{$seq_member_id1};
      #print STDERR "seq_member_id1 $seq_member_id -> ", $protein1->stable_id, " on root_id ", $gene_tree->root_id(), "\n";
      my $cdna = $protein1->alignment_string($seq_type);
      print STDERR "cnda $cdna\n" if $self->debug;
        # We start with the original cdna alignment string of the first gene, and
        # add the position in the other cdna for every gap position, and iterate
        # through all the other cdnas
        # cdna1 = AAA AAA AAA AAA AAA --- --- --- --- --- --- --- --- --- --- --- ---
        # cdna2 = --- --- --- --- --- --- TTT TTT TTT TTT TTT --- --- --- --- --- ---
        # become
        # cdna1 = AAA AAA AAA AAA AAA --- TTT TTT TTT TTT TTT --- --- --- --- --- ---
        # and now then paired with 3, they becomes the full gene model:
        # cdna3 = --- --- --- --- --- --- --- --- --- --- --- --- CCC CCC CCC CCC CCC
        # and form:
        # cdna1 = AAA AAA AAA AAA AAA --- TTT TTT TTT TTT TTT --- CCC CCC CCC CCC CCC
      foreach my $rseq_member_id2 (@$partial_genes) {
        my $protein2 = $leaf_by_seq_member_id{$rseq_member_id2->[0]};
        #print STDERR "seq_member_id2 ", $rseq_member_id2, " ", $protein2->stable_id, "\n";
        $split_genes{$protein2->seq_member_id} = $seq_member_id1;
        print STDERR "Joining in ", $protein1->stable_id, " and ", $protein2->stable_id, " in input cdna alignment\n" if ($self->debug);
        my $other_cdna = $protein2->alignment_string($seq_type);
        print STDERR "cnda2 $other_cdna\n" if $self->debug;
        $cdna =~ s/-/substr($other_cdna, pos($cdna), 1)/eg;
        print STDERR "cnda $cdna\n" if $self->debug;


            # Remove the split genes and all the parents that are left without members
            my $node = $protein2->parent;
            $protein2->disavow_parent();
            while ($node->get_child_count() == 0) {
                my $parent = $node->parent;
                $node->disavow_parent();
                $node = $parent;
            }
            push @{$self->param('hidden_genes')}, $protein2;

      }
        # We then directly override the cached alignment_string_cds
        # entry in the hash, which will be used next time it is called
      $protein1->{'alignment_string'.($seq_type || '')} = $cdna;
    }

    if (scalar(keys %split_genes)) {
        $gene_tree->{'_root'} = $gene_tree->root->minimize_tree;
    }

    # Removing duplicate sequences of split genes
    print STDERR "split_genes list: ", Dumper(\%split_genes), "\n" if $self->debug;
    warn sprintf("Removed %d split genes, %d leaves left in the tree\n", scalar(keys %split_genes), scalar(@{$gene_tree->get_all_leaves})) if $self->debug;
    $self->param('split_genes', \%split_genes);
}



sub dumpTreeMultipleAlignmentToWorkdir {
    my $self = shift;
    my $gene_tree = shift;
    my $format = shift;
    my $simple_align_options = shift || {};

    my $removed_columns = undef;
    if ($self->param('removed_columns')) {
        if ($gene_tree->has_tag('removed_columns')) {
            my @removed_columns = eval($gene_tree->get_value_for_tag('removed_columns'));
            $removed_columns = \@removed_columns;
            print Dumper $removed_columns if ( $self->debug() );
        } else {
            $self->warning(sprintf("The 'removed_columns' is missing from tree dbID=%d\n", $gene_tree->dbID));
        }
    }

    my $aln_file = $self->worker_temp_directory.sprintf('align.%d.%s', $gene_tree->dbID || 0, $format);

    $gene_tree->print_alignment_to_file( $aln_file,
        -FORMAT => $format,
        -ID_TYPE => 'MEMBER',
        $self->param('cdna') ? (-SEQ_TYPE => 'cds') : (),
        -STOP2X => 1,
        -REMOVED_COLUMNS => $removed_columns,
        %$simple_align_options,
    );

    unless(-e $aln_file and -s $aln_file) {
        die "There are no alignments in '$aln_file', cannot continue";
    }

    return $aln_file;
}



sub store_genetree
{
    my $self = shift;
    my $tree = shift;

    printf("PHYML::store_genetree\n") if($self->debug);
    my $treenode_adaptor = $tree->adaptor->db->get_GeneTreeNodeAdaptor;

    $tree->root->build_leftright_indexing(1);
    $self->call_within_transaction(sub {
        $tree->adaptor->store($tree);
        $treenode_adaptor->delete_nodes_not_in_tree($tree->root);
    });

    # We can update the tags outside of the transaction because nothing is
    # linked to them. Nothing will break if they're partially there
    # Note that the direct methods here are faster than calling
    # sync_tags_to_database() on each node
    my $all_nodes = $tree->get_all_nodes;
    my @leaves = grep {$_->is_leaf} @$all_nodes;
    $treenode_adaptor->_wipe_all_tags($tree->root);
    $treenode_adaptor->_wipe_all_tags(\@leaves, 1);
    $treenode_adaptor->_store_all_tags($all_nodes);

    $self->store_tree_tags($tree);

    if($self->debug >1) {
        print("done storing - now print\n");
        $tree->print_tree;
    }
}

sub interpret_treebest_tags
{
    my $self = shift;
    my $node = shift;
    my $ref_support = shift;

    if ($self->debug) {
        print 'storing tags for:'; $node->print_node;
    }

    my $treebest_tag = { '_tags' => $node->get_tagvalue_hash };
    bless $treebest_tag, 'Bio::EnsEMBL::Compara::Taggable';
    $node->{'_tags'} = {};

    my $node_type = '';
    if (not $node->is_leaf) {
        if ($treebest_tag->has_tag('gene_split')) {
            $node_type = 'gene_split';
        } elsif ($treebest_tag->get_tagvalue("DD", 0)) {
            $node_type = 'dubious';
        } elsif ($treebest_tag->get_tagvalue('Duplication', '') eq '1') {
            $node_type = 'duplication';
        } else {
            $node_type = 'speciation';
        }
        print "node_type: $node_type\n" if ($self->debug);
        $node->add_tag('node_type', $node_type);
    }

    if ($treebest_tag->has_tag("E")) {
        my $n_lost = $treebest_tag->get_tagvalue("E");
        $n_lost =~ s/.{2}//;        # get rid of the initial $-
        my @lost_taxa = split('-', $n_lost);
        print "lost_species_tree_node_id : $n_lost\n" if ($self->debug);
        $node->add_tag('lost_species_tree_node_id', \@lost_taxa);
    }
    return if $node->is_leaf;

    if ($treebest_tag->has_tag('T') and $self->param('store_tree_support')) {
        my $binary_support = $treebest_tag->get_tagvalue('T');
        my $i = 0;
        my @tree_support = ();
        while ($binary_support) {
            if ($binary_support & 1) {
                push @tree_support, $ref_support->[$i];
            }
            $binary_support >>= 1;
            $i++;
        }
        print 'tree_support : ', join(',', @tree_support), "\n" if ($self->debug);
        $node->add_tag('tree_support', \@tree_support) if @tree_support;
    }

    my %mapped_tags = ('B' => 'bootstrap', 'DCS' => 'duplication_confidence_score', 'S' => 'species_tree_node_id');
    foreach my $tag (keys %mapped_tags) {
        my $db_tag = $mapped_tags{$tag};
        if ($treebest_tag->has_tag($tag)) {
            my $value = $treebest_tag->get_tagvalue($tag);
            print "$tag as $db_tag: $value\n" if ($self->debug);
            $node->add_tag($db_tag, $value);
        }
    }
    $node->add_tag('duplication_confidence_score', 1) if $node_type eq 'gene_split';

    foreach my $child (@{$node->children}) {
        $self->interpret_treebest_tags($child, $ref_support);
    }
}

sub parse_newick_into_tree {
  my $self = shift;
  my $newick = shift;
  my $tree = shift;
  my $ref_support = shift;
  
  return undef if $newick =~ /^_null_/;

  # List all the GeneTreeNode that have to be stored
  my %old_leaves;
  foreach my $node (@{$tree->get_all_leaves}) {
    $old_leaves{$node->seq_member_id} = $node;
  }
  # Top it up with the genes that have been hidden (split genes, long branches, etc)
  if ($self->param('hidden_genes')) {
    foreach my $hidden_member (@{$self->param('hidden_genes')}) {
      $old_leaves{$hidden_member->seq_member_id} = $hidden_member unless $old_leaves{$hidden_member->seq_member_id};
    }
  }

  my $newroot = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick, "Bio::EnsEMBL::Compara::GeneTreeNode");
  print  "Tree loaded from file:\n";
  $newroot->print_tree(20) if($self->debug > 1);

  # get rid of the taxon_id needed by njtree -- name tag
  my %new_leaves = ();
  foreach my $leaf (@{$newroot->get_all_leaves}) {
    my $njtree_phyml_name = $leaf->name;
    $njtree_phyml_name =~ /^(\d+)/;
    my $seq_member_id = $1;
    $new_leaves{$seq_member_id} = $leaf;
    $leaf->name($seq_member_id);
  }

  # Insert back the split genes that have been removed by merge_split_genes()
  if ($self->param('check_split_genes')) {

    my $split_genes = $self->param('split_genes');
    print  "Retrieved split_genes list: ", Dumper($split_genes), "\n" if $self->debug;
    if (scalar(keys %$split_genes)) {
      while (my ($this_member_id, $other_member_id) = each %$split_genes) {
        my $split_gene_leaf = new Bio::EnsEMBL::Compara::GeneTreeNode;
        $split_gene_leaf->name($this_member_id);       # To match the naming convention of the other leaves
        print $this_member_id." is split_gene of $other_member_id\n" if $self->debug;
        my $othernode = $new_leaves{$other_member_id};
        die sprintf("Couldn't find the node '%d' in the tree (to re-create '%d').\nNewick string is:\n%s\n", $other_member_id, $this_member_id, $newick) unless $othernode;
        print  "$split_gene_leaf is split_gene of $othernode\n" if $self->debug;
        my $new_internal_node = new Bio::EnsEMBL::Compara::GeneTreeNode;
        $othernode->parent->add_child($new_internal_node);
        $new_internal_node->add_child($othernode);
        $new_internal_node->add_child($split_gene_leaf);
        $new_internal_node->add_tag('gene_split', 1);
        $new_internal_node->add_tag('S', $othernode->get_tagvalue('S'));
        $split_gene_leaf->add_tag('S', $othernode->get_tagvalue('S'));
        $new_internal_node->print_tree(10) if $self->debug;
      }
      print  "Tree after split genes insertions:\n";
      $newroot->print_tree(20) if($self->debug > 1);
    }
  }

  foreach my $leaf (@{$newroot->get_all_leaves}) {
    my $seq_member_id = $leaf->name();
    my $old_leaf = $old_leaves{$seq_member_id};
    if (not $old_leaf) {
	  #In case the tree is been updated (copied from previous_db) we need to:
	  #set the updated node to use the temporary id "0" to avoid dammaging other trees in the database
	  #We set the children_loaded=1 to tell the API not to load the leaf
	  #Then we "next" the loop
      $leaf->print_node;
	  bless $leaf, 'Bio::EnsEMBL::Compara::GeneTreeMember';
	  $leaf->node_id(0);
	  $leaf->seq_member_id($seq_member_id);
	  $leaf->adaptor($tree->adaptor->db->get_GeneTreeNodeAdaptor);
	  $leaf->{'_children_loaded'} = 1;
	  next;
    }
    bless $leaf, 'Bio::EnsEMBL::Compara::GeneTreeMember';
    $old_leaf->Bio::EnsEMBL::Compara::AlignedMember::copy($leaf);
    $leaf->node_id($old_leaf->node_id);
    $leaf->adaptor($old_leaf->adaptor);
    $leaf->{'_children_loaded'} = 1;
  }
  print  "Tree with GeneTreeNode objects:\n";
  $newroot->print_tree(20) if($self->debug > 1);

  $newroot->node_id($tree->root_id);
  $tree->root->parent->add_child($newroot) if $tree->root->parent;
  $newroot->distance_to_parent($tree->root->distance_to_parent);
  $newroot->adaptor($tree->root->adaptor);
  $newroot->tree($tree);
  $tree->root->release_tree;
  $tree->{'_root'} = $newroot;

  $tree->root->print_tree if($self->debug);
  # check here on the leaf to test if they all are GeneTreeMembers as
  # minimize_tree/minimize_node might not work properly
  foreach my $leaf (@{$tree->root->get_all_leaves}) {
    assert_ref($leaf, 'Bio::EnsEMBL::Compara::GeneTreeMember');
  }
  $self->interpret_treebest_tags($tree->root, $ref_support);
  return $tree;
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
        if ($node->has_tag('node_type') and ($node->get_tagvalue('node_type') ne 'speciation')) {
            $num_dups++;
        } else {
            $num_specs++;
        }
    }
    $tree->store_tag("tree_num_dup_nodes",$num_dups);
    $tree->store_tag("tree_num_spec_nodes",$num_specs);

    # The number of species
    my %hash_species = ();
    map {$hash_species{$_->genome_db_id}=1} @leaves;
    # Could be renamed to 'tree_num_species' !
    $tree->store_tag('spec_count', scalar keys %hash_species);

    print "Done storing stuff!\n" if ($self->debug);
}

sub store_tree_into_clusterset {
    my $self = shift;
    my $newtree = shift;
    my $clusterset = shift;

    my $clusterset_leaf = new Bio::EnsEMBL::Compara::GeneTreeNode;
    $clusterset_leaf->no_autoload_children();
    $clusterset->root->add_child($clusterset_leaf);
    $clusterset_leaf->add_child($newtree->root);
    $newtree->clusterset_id($clusterset->clusterset_id);

    $self->call_within_transaction(sub {
        $clusterset->adaptor->db->get_GeneTreeNodeAdaptor->store_nodes_rec($clusterset_leaf);
    });
}

sub fetch_or_create_other_tree {
    my ($self, $clusterset, $tree, $remove_previous_copy) = @_;

    if (not defined $self->param('other_trees')) {
        my %other_trees;
        foreach my $other_tree (@{$tree->adaptor->fetch_all_linked_trees($tree)}) {
            $other_tree->preload();
            $other_trees{$other_tree->clusterset_id} = $other_tree;
        }
        $self->param('other_trees', \%other_trees);
    }

    if ($remove_previous_copy and exists ${$self->param('other_trees')}{$clusterset->clusterset_id}) {
		warn "deleting the previous tree\n";
		$tree->adaptor->delete_tree(${$self->param('other_trees')}{$clusterset->clusterset_id});
		delete ${$self->param('other_trees')}{$clusterset->clusterset_id};
	}

    if (not exists ${$self->param('other_trees')}{$clusterset->clusterset_id}) {
        my $newtree = $tree->deep_copy();
        $newtree->stable_id(undef);
        # Reformat things
        foreach my $member (@{$newtree->get_all_Members}) {
            $member->cigar_line(undef);
            $member->{'_children_loaded'} = 1;
        }
        $newtree->ref_root_id($tree->ref_root_id || $tree->root_id);
        $self->store_tree_into_clusterset($newtree, $clusterset);
        ${$self->param('other_trees')}{$clusterset->clusterset_id} = $newtree;
    }

    return ${$self->param('other_trees')}{$clusterset->clusterset_id};
}

sub store_alternative_tree {
    my ($self, $newick, $clusterset_id, $ref_tree, $ref_support, $remove_previous_tree) = @_;
    my $clusterset = $ref_tree->adaptor->fetch_all(-tree_type => 'clusterset', -clusterset_id => $clusterset_id)->[0];
    if (not defined $clusterset) {
        $self->throw("The clusterset_id '$clusterset_id' is not defined. Cannot store the alternative tree");
        return;
    }
    my $newtree = $self->fetch_or_create_other_tree($clusterset, $ref_tree, $remove_previous_tree);
    return undef unless $self->parse_newick_into_tree($newick, $newtree, $ref_support);
    $self->store_genetree($newtree);
    return $newtree;
}

sub parse_filtered_align {
    my ($self, $alnfile_ini, $alnfile_filtered, $cdna, $tree_to_delete_nodes) = @_;

    # Loads the filtered alignment strings
    my %hash_filtered_strings = ();
    {
        my $alignio = Bio::AlignIO->new(-file => $alnfile_filtered, -format => 'fasta');
        my $aln = $alignio->next_aln;

        unless ($aln) {
            $self->warning("Cannot read the filtered alignment '$alnfile_filtered'\n");
            return;
        }

        foreach my $seq ($aln->each_seq) {
            # Delete empty sequences => Sequences with only gaps and 'X's
            # for instance: ---------XXXXX---X---XXXX
            next if  $cdna and $seq->seq() =~ /^[Nn\-]*$/;
            next if !$cdna and $seq->seq() =~ /^[Xx\-]*$/;
            $hash_filtered_strings{$seq->display_id()} = $seq->seq();
        }
    }

    my %hash_initial_strings = ();
    my @missing_members = ();
    {
        my $alignio = Bio::AlignIO->new(-file => $alnfile_ini, -format => 'fasta');
        my $aln = $alignio->next_aln or die "The input alignment '$alnfile_ini' cannot be read";

        foreach my $seq ($aln->each_seq) {
            if (exists $hash_filtered_strings{$seq->display_id()}) {
                $hash_initial_strings{$seq->display_id()} = $seq->seq();
            } else {
                push @missing_members, $seq->display_id();
            }
        }
    }
    my $all_missing_members = join('/', @missing_members);

    if ($tree_to_delete_nodes and scalar(@missing_members)) {
        my $treenode_adaptor = $tree_to_delete_nodes->adaptor->db->get_GeneTreeNodeAdaptor;

        warn sprintf("leaves=%d ini_aln=%d filt_aln=%d\n", scalar(@{$tree_to_delete_nodes->get_all_leaves()}), scalar(keys %hash_initial_strings), scalar(keys %hash_filtered_strings));

        foreach my $leaf (@{$tree_to_delete_nodes->get_all_leaves()}) {
            next if exists $hash_filtered_strings{$leaf->seq_member_id};

            $self->call_within_transaction(sub{
                $treenode_adaptor->remove_seq_member($leaf);
            });
        }
        $self->param('removed_members', 1);
        $tree_to_delete_nodes->store_tag('n_removed_members', scalar(@missing_members));
        $tree_to_delete_nodes->store_tag('removed_members', $all_missing_members);
        $tree_to_delete_nodes->store_tag('gene_count', scalar(@{$tree_to_delete_nodes->get_all_leaves}) );
    } elsif (scalar(@missing_members)) {
        $self->param('gene_tree')->store_tag('n_removable_members', scalar(@missing_members));
        $self->param('gene_tree')->store_tag('removable_members', $all_missing_members);
    }

    return Bio::EnsEMBL::Compara::Utils::Cigars::identify_removed_columns(\%hash_initial_strings, \%hash_filtered_strings, $cdna);
}



1;
