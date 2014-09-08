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
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub dumpTreeMultipleAlignmentToWorkdir {
  my $self = shift;
  my $gene_tree = shift;
  

  my $file_root = $self->worker_temp_directory. ($gene_tree->dbID || $gene_tree->gene_align_id);
  $file_root =~ s/\/\//\//g;  # converts any // in path to /

  my $aln_file = $file_root . '.aln';
  return $aln_file if(-e $aln_file);
  if($self->debug) {
    my $leafcount = scalar(@{$gene_tree->get_all_Members});
    printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $leafcount);
    print("aln_file = '$aln_file'\n");
  }

  my %leaf_by_seq_member_id = (map {$_->seq_member_id => $_} @{ $gene_tree->get_all_Members });

  print STDERR "fetching alignment\n" if ($self->debug);
  my $seq_type = $self->param('cdna') ? 'cds' : undef;

  ########################################
  # Gene split mirroring code
  #
  # This will have the effect of grouping the different
  # fragments of a gene split event together in a subtree
  #
  if ($self->param('check_split_genes')) {
    my %split_genes;
    my $sth = $self->compara_dba->dbc->prepare('SELECT DISTINCT gene_split_id FROM split_genes JOIN gene_tree_node USING (seq_member_id) WHERE root_id = ?');
    $sth->execute($gene_tree->root_id());
    my $gene_splits = $sth->fetchall_arrayref();
    $sth->finish;
    $sth = $self->compara_dba->dbc->prepare('SELECT seq_member_id FROM split_genes JOIN gene_tree_node USING (seq_member_id) WHERE root_id = ? AND gene_split_id = ? ORDER BY seq_member_id');
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
        $split_genes{$protein2->{_tmp_name}} = $protein1->{_tmp_name};
        #print STDERR Dumper(%split_genes);
        print STDERR "Joining in ", $protein1->stable_id, " and ", $protein2->stable_id, " in input cdna alignment\n" if ($self->debug);
        my $other_cdna = $protein2->alignment_string($seq_type);
        print STDERR "cnda2 $other_cdna\n" if $self->debug;
        $cdna =~ s/-/substr($other_cdna, pos($cdna), 1)/eg;
        print STDERR "cnda $cdna\n" if $self->debug;
      }
        # We then directly override the cached alignment_string_cds
        # entry in the hash, which will be used next time it is called
      $protein1->{$self->param('cdna') ? 'alignment_string_cds' : 'alignment_string'} = $cdna;
    }

    # Removing duplicate sequences of split genes
    print STDERR "split_genes hash: ", Dumper(\%split_genes), "\n" if $self->debug;
    $self->param('split_genes', \%split_genes);
  }
 
  # Getting the multiple alignment
  my $sa = $gene_tree->get_SimpleAlign(
     -id_type => 'MEMBER',
     -APPEND_SPECIES_TREE_NODE_ID => 1,
     -stop2x => 1,
     -SEQ_TYPE => $seq_type,
  );
  if ($self->param('check_split_genes')) {
    foreach my $gene_to_remove (keys %{$self->param('split_genes')}) {
      $sa->remove_seq($sa->each_seq_with_id($gene_to_remove));
    }
  }

  if ($self->param('remove_columns')) {
    if ($gene_tree->has_tag('removed_columns')) {
      my @removed_columns = eval($gene_tree->get_value_for_tag('removed_columns'));
      print Dumper \@removed_columns if ( $self->debug() );
      $sa = $sa->remove_columns(@removed_columns) if scalar(@removed_columns);
    } else {
      $self->warning(sprintf("The 'removed_columns' is missing from tree dbID=%d\n", $gene_tree->dbID));
    }
  }

  $sa->set_displayname_flat(1);
  # Now outputing the alignment
  open my $fh, ">", $aln_file or die "Could not open '$aln_file' for writing : $!";
  my $alignIO = Bio::AlignIO->newFh( -fh => $fh, -format => ($self->param('aln_format') || "fasta"));
  print $alignIO $sa;
  close $fh;

  unless(-e $aln_file and -s $aln_file) {
    die "There are no alignments in '$aln_file', cannot continue";
  }

  return $aln_file
}


sub dumpAlignedMemberSetAsStockholm {

    my $self = shift;
    my $gene_tree = shift;

    my $file_root = $self->worker_temp_directory.'/align';
    $file_root =~ s/\/\//\//g;  # converts any // in path to /

    print STDERR "fetching alignment\n" if ($self->debug);

    # Getting the multiple alignment
    my $sa = $gene_tree->get_SimpleAlign(
            -id_type => 'MEMBER',
            $self->param('cdna') ? (-seq_type => 'cds') : (),
            -stop2x => 1,
            );

    $sa->set_displayname_flat(1);

    # Now outputing the alignment
    my $stk_file = $file_root . '.stk';
    open my $fh, ">", $stk_file or die "Could not open '$stk_file' for writing : $!";
    my $alignIO = Bio::AlignIO->newFh( -fh => $fh, -format => "stockholm");
    print $alignIO $sa;
    close $fh;
    return $stk_file;
}



sub store_genetree
{
    my $self = shift;
    my $tree = shift;
    my $ref_support = shift;

    printf("PHYML::store_genetree\n") if($self->debug);

    $tree->root->build_leftright_indexing(1);

    # Make sure the same commands are inside and outside of the transaction
    if ($self->param('do_transactions')) {
        my $helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $self->compara_dba->dbc);
        $helper->transaction(
            -RETRY => 3, -PAUSE => 5,
            -CALLBACK => sub {
                $self->compara_dba->get_GeneTreeAdaptor->store($tree);
                $self->compara_dba->get_GeneTreeNodeAdaptor->delete_nodes_not_in_tree($tree->root);
            }
        );
    } else {
        $self->compara_dba->get_GeneTreeAdaptor->store($tree);
        $self->compara_dba->get_GeneTreeNodeAdaptor->delete_nodes_not_in_tree($tree->root);
    }


    if($self->debug >1) {
        print("done storing - now print\n");
        $tree->print_tree;
    }

    if ($tree->root->get_child_count == 2) {
        $self->store_node_tags($tree->root, $ref_support);
        $self->store_tree_tags($tree);
    }
}

sub store_node_tags
{
    my $self = shift;
    my $node = shift;
    my $ref_support = shift;

    if ($self->debug) {
        print 'storing tags for:'; $node->print_node;
    }

    my $node_type = '';
    if ($node->is_leaf) {
        $node->delete_tag('node_type');
    } else {
        if ($node->has_tag('gene_split')) {
            $node_type = 'gene_split';
        } elsif ($node->get_tagvalue("DD", 0)) {
            $node_type = 'dubious';
        } elsif ($node->get_tagvalue('Duplication', '') eq '1') {
            $node_type = 'duplication';
        } else {
            $node_type = 'speciation';
        }
        print "node_type: $node_type\n" if ($self->debug);
        $node->store_tag('node_type', $node_type);
    }

    $node->delete_tag('lost_species_tree_node_id');
    if ($node->has_tag("E")) {
        my $n_lost = $node->get_tagvalue("E");
        $n_lost =~ s/.{2}//;        # get rid of the initial $-
        my @lost_taxa = split('-', $n_lost);
        my $topup = 0;
        foreach my $taxon (@lost_taxa) {
            print "lost_species_tree_node_id : $taxon\n" if ($self->debug);
            $node->store_tag('lost_species_tree_node_id', $taxon, $topup);
            $topup = 1;
        }
    }
    return if $node->is_leaf;

    $node->delete_tag('tree_support');
    if ($node->has_tag('T') and $self->param('store_tree_support')) {
        my $binary_support = $node->get_tagvalue('T');
        my $i = 0;
        while ($binary_support) {
            if ($binary_support & 1) {
                print 'tree_support : ', $ref_support->[$i], "\n" if ($self->debug);
                $node->store_tag('tree_support', $ref_support->[$i], 1);
            }
            $binary_support >>= 1;
            $i++;
        }
    }

    my %mapped_tags = ('B' => 'bootstrap', 'SIS' => 'species_intersection_score', 'S' => 'species_tree_node_id');
    foreach my $tag (keys %mapped_tags) {
        my $db_tag = $mapped_tags{$tag};
        if ($node->has_tag($tag)) {
            my $value = $node->get_tagvalue($tag);
            print "$tag as $db_tag: $value\n" if ($self->debug);
            $node->store_tag($db_tag, $value);
        } else {
            $node->delete_tag($db_tag);
        }
    }

    foreach my $child (@{$node->children}) {
        $self->store_node_tags($child, $ref_support);
    }
}

sub parse_newick_into_tree {
  my $self = shift;
  my $newick = shift;
  my $tree = shift;
  
  return undef if $newick =~ /^_null_/;
  #cleanup old tree structure- 
  #  flatten and reduce to only GeneTreeMember leaves
  my %leaves;
  foreach my $node (@{$tree->get_all_Members}) {
    $leaves{$node->seq_member_id} = $node;
  }

  my $newroot = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($newick, "Bio::EnsEMBL::Compara::GeneTreeNode");
  print  "Tree loaded from file:\n";
  $newroot->print_tree(20) if($self->debug > 1);

  my $split_genes = $self->param('split_genes');

  if (defined $split_genes) {
    print  "Retrieved split_genes hash: ", Dumper($split_genes) if $self->debug;
    my $nsplits = 0;
    while ( my ($name, $other_name) = each(%{$split_genes})) {
        print  "$name is split_gene of $other_name\n" if $self->debug;
        my $node = new Bio::EnsEMBL::Compara::GeneTreeNode;
        $node->name($name);
        my $othernode = $newroot->find_node_by_name($other_name);
        print  "$node is split_gene of $othernode\n" if $self->debug;
        my $newnode = new Bio::EnsEMBL::Compara::GeneTreeNode;
        $nsplits++;
        $othernode->parent->add_child($newnode);
        $newnode->add_child($othernode);
        $newnode->add_child($node);
        $newnode->add_tag('gene_split', 1);
        $newnode->add_tag('S', $othernode->get_tagvalue('S'));
        $newnode->print_tree(10) if $self->debug;
    }
  }
  print  "Tree after split_genes insertions:\n";
  $newroot->print_tree(20) if($self->debug > 1);

  # get rid of the taxon_id needed by njtree -- name tag
  foreach my $leaf (@{$newroot->get_all_leaves}) {
    my $njtree_phyml_name = $leaf->get_tagvalue('name');
    $njtree_phyml_name =~ /(\d+)\_\d+/;
    my $seq_member_id = $1;
    my $old_leaf = $leaves{$seq_member_id};
    if (not $old_leaf) {
      $leaf->print_node;
      die "unable to find seq_member '$seq_member_id' (in '$njtree_phyml_name', from newick '$newick')";
    }
    bless $leaf, 'Bio::EnsEMBL::Compara::GeneTreeMember';
    $leaf->seq_member_id($seq_member_id);
    $leaf->gene_member_id($old_leaf->gene_member_id);
    $leaf->cigar_line($old_leaf->cigar_line);
    $leaf->node_id($old_leaf->node_id);
    $leaf->taxon_id($old_leaf->taxon_id);
    $leaf->stable_id($old_leaf->stable_id);
    $leaf->adaptor($old_leaf->adaptor);
    $leaf->add_tag('name', $seq_member_id);
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

    # Make sure the same commands are inside and outside of the transaction
    if ($self->param('do_transactions')) {
        my $helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $self->compara_dba->dbc);
        $helper->transaction(
            -RETRY => 3, -PAUSE => 5,
            -CALLBACK => sub {
                $clusterset->adaptor->db->get_GeneTreeNodeAdaptor->store_nodes_rec($clusterset_leaf);
            }
        );
    } else {
        $clusterset->adaptor->db->get_GeneTreeNodeAdaptor->store_nodes_rec($clusterset_leaf);
    }



}

sub fetch_or_create_other_tree {
    my ($self, $clusterset, $tree) = @_;

    if (not defined $self->param('other_trees')) {
        my %other_trees;
        foreach my $other_tree (@{$self->compara_dba->get_GeneTreeAdaptor->fetch_all_linked_trees($tree)}) {
            $other_tree->preload();
            $other_trees{$other_tree->clusterset_id} = $other_tree;
        }
        $self->param('other_trees', \%other_trees);
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
    my ($self, $newick, $clusterset_id, $ref_tree, $ref_support) = @_;
    my $clusterset = $self->compara_dba->get_GeneTreeAdaptor->fetch_all(-tree_type => 'clusterset', -clusterset_id => $clusterset_id)->[0];
    if (not defined $clusterset) {
        $self->throw("The clusterset_id '$clusterset_id' is not defined. Cannot store the alternative tree");
        return;
    }
    my $newtree = $self->fetch_or_create_other_tree($clusterset, $ref_tree);
    return undef unless $self->parse_newick_into_tree($newick, $newtree);
    $self->store_genetree($newtree, $ref_support);
    $newtree->release_tree;
    return $newtree;
}

sub parse_filtered_align {
    my ($self, $alnfile_ini, $alnfile_filtered, $remove_missing_members, $cdna) = @_;

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
    my $missing_members = 0;
    {
        my $alignio = Bio::AlignIO->new(-file => $alnfile_ini, -format => 'fasta');
        my $aln = $alignio->next_aln or die "The input alignment '$alnfile_ini' cannot be read";

        foreach my $seq ($aln->each_seq) {
            if (exists $hash_filtered_strings{$seq->display_id()}) {
                $hash_initial_strings{$seq->display_id()} = $seq->seq();
            } else {
                $missing_members++;
            }
        }
    }

    if ($remove_missing_members and $missing_members) {
        my $treenode_adaptor = $self->compara_dba->get_GeneTreeNodeAdaptor;

        foreach my $leaf (@{$self->param('gene_tree')->get_all_leaves()}) {
            next if exists $hash_filtered_strings{$leaf->{_tmp_name}};
            $leaf->disavow_parent;
            $treenode_adaptor->delete_flattened_leaf( $leaf );
            my $sth = $self->compara_dba->dbc->prepare('INSERT IGNORE INTO removed_member (node_id, stable_id, genome_db_id) VALUES (?,?,?)');
            print $self->param('gene_tree_id').", $leaf->stable_id, $leaf->genome_db_id, \n" ;
            $sth->execute($leaf->node_id, $leaf->stable_id, $leaf->genome_db_id );
            $sth->finish;
        }
        $self->param('removed_members', $missing_members);
        $self->param('default_gene_tree')->store_tag('n_removed_members', $missing_members);
        $self->param('default_gene_tree')->store_tag('gene_count', scalar(@{$self->param('gene_tree')->get_all_leaves}) );
    } elsif ($missing_members) {
        $self->param('default_gene_tree')->store_tag('n_removable_members', $missing_members);
    }

    return Bio::EnsEMBL::Compara::Utils::Cigars::identify_removed_columns(\%hash_initial_strings, \%hash_filtered_strings, $cdna ? 3 : 1);
}



1;
