package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree;

use strict;

use Data::Dumper;

use Bio::EnsEMBL::Utils::Scalar qw(:assert);
use Bio::EnsEMBL::Compara::AlignedMember;
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub _name_for_prot {
    my $self = shift;
    my $prot = shift;
    return ($prot->member_id)."_".($self->param('use_genomedb_id') ? $prot->genome_db_id : $prot->taxon_id);
}

sub dumpTreeMultipleAlignmentToWorkdir {
  my $self = shift;
  my $gene_tree = shift;
  my $convert_to_stockholm = shift;
  
  my $leafcount = scalar(@{$gene_tree->get_all_Members});

  my $file_root = $self->worker_temp_directory. ($gene_tree->dbID || $gene_tree->gene_align_id);
  $file_root =~ s/\/\//\//g;  # converts any // in path to /

  my $aln_file = $file_root . '.aln';
  return $aln_file if(-e $aln_file);
  if($self->debug) {
    printf("dumpTreeMultipleAlignmentToWorkdir : %d members\n", $leafcount);
    print("aln_file = '$aln_file'\n");
  }

  # Using append_taxon_id will give nice seqnames_taxonids needed for
  # njtree species_tree matching
  my %sa_params = $self->param('use_genomedb_id') ? ('-APPEND_GENOMEDB_ID', 1) : ('-APPEND_TAXON_ID', 1);

  print STDERR "fetching alignment\n" if ($self->debug);

  ########################################
  # Gene split mirroring code
  #
  # This will have the effect of grouping the different
  # fragments of a gene split event together in a subtree
  #
  if ($self->param('check_split_genes')) {
    my %split_genes;
    my $sth = $self->compara_dba->dbc->prepare('SELECT DISTINCT gene_split_id FROM split_genes JOIN gene_tree_node USING (member_id) WHERE root_id = ?');
    $sth->execute($self->param('gene_tree_id'));
    my $gene_splits = $sth->fetchall_arrayref();
    $sth->finish;
    $sth = $self->compara_dba->dbc->prepare('SELECT node_id FROM split_genes JOIN gene_tree_node USING (member_id) WHERE root_id = ? AND gene_split_id = ?');
    foreach my $gene_split (@$gene_splits) {
      $sth->execute($self->param('gene_tree_id'), $gene_split->[0]);
      my $partial_genes = $sth->fetchall_arrayref;
      my $node1 = shift @$partial_genes;
      my $protein1 = $gene_tree->root->find_leaf_by_node_id($node1->[0]);
      #print STDERR "node1 ", $node1, " ", $protein1, "\n";
      my $name1 = $self->_name_for_prot($protein1);
      my $cdna = $protein1->cdna_alignment_string;
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
      foreach my $node2 (@$partial_genes) {
        my $protein2 = $gene_tree->root->find_leaf_by_node_id($node2->[0]);
        #print STDERR "node2 ", $node2, " ", $protein2, "\n";
        my $name2 = $self->_name_for_prot($protein2);
        $split_genes{$name2} = $name1;
        #print STDERR Dumper(%split_genes);
        print STDERR "Joining in ", $protein1->stable_id, " / $name1 and ", $protein2->stable_id, " / $name2 in input cdna alignment\n" if ($self->debug);
        my $other_cdna = $protein2->cdna_alignment_string;
        print STDERR "cnda2 $other_cdna\n" if $self->debug;
        $cdna =~ s/-/substr($other_cdna, pos($cdna), 1)/eg;
        print STDERR "cnda $cdna\n" if $self->debug;
      }
        # We then directly override the cached cdna_alignment_string
        # hash, which will be used next time is called for
      $protein1->{'cdna_alignment_string'} = $cdna;
    }

    # Removing duplicate sequences of split genes
    print STDERR "split_genes hash: ", Dumper(\%split_genes), "\n" if $self->debug;
    $self->param('split_genes', \%split_genes);
  }
 
  # Getting the multiple alignment
  my $sa = $gene_tree->get_SimpleAlign(
     -id_type => 'MEMBER',
     -cdna => $self->param('cdna'),
     -stop2x => 1,
     %sa_params,
  );
  if ($self->param('check_split_genes')) {
    foreach my $gene_to_remove (keys %{$self->param('split_genes')}) {
      $sa->remove_seq($sa->each_seq_with_id($gene_to_remove));
    }
  }
  $sa->set_displayname_flat(1);
  # Now outputing the alignment
  open(OUTSEQ, ">$aln_file") or die "Could not open '$aln_file' for writing : $!";
  my $alignIO = Bio::AlignIO->newFh( -fh => \*OUTSEQ, -format => "fasta");
  print $alignIO $sa;
  close OUTSEQ;

  unless(-e $aln_file and -s $aln_file) {
    die "There are no alignments in '$aln_file', cannot continue";
  }

  return $aln_file unless $convert_to_stockholm;

  print STDERR "Using sreformat to change to stockholm format\n" if ($self->debug);
  my $stk_file = $file_root . '.stk';

  my $sreformat_exe = $self->param('sreformat_exe')
        or die "'sreformat_exe' is an obligatory parameter";

  die "Cannot execute '$sreformat_exe'" unless(-x $sreformat_exe);

  my $cmd = "$sreformat_exe stockholm $aln_file > $stk_file";

  if(system($cmd)) {
    die "Error running command [$cmd] : $!";
  }
  unless(-e $stk_file and -s $stk_file) {
    die "'$cmd' did not produce any data in '$stk_file'";
  }

  return $stk_file;
}

sub store_genetree
{
    my $self = shift;
    my $tree = shift;
    my $ref_support = shift;

    printf("PHYML::store_genetree\n") if($self->debug);

    $tree->root->build_leftright_indexing(1);
    $self->compara_dba->get_GeneTreeAdaptor->store($tree);
    $self->compara_dba->get_GeneTreeNodeAdaptor->delete_nodes_not_in_tree($tree->root);

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
    if (not $node->is_leaf) {
        if ($node->has_tag('gene_split')) {
            $node_type = 'gene_split';
        } elsif ($node->get_tagvalue("DD", 0)) {
            $node_type = 'dubious';
        } elsif ($node->get_tagvalue('Duplication', '') eq '1') {
            $node_type = 'duplication';
        } else {
            $node_type = 'speciation';
        }
        $node->store_tag('node_type', $node_type);
        print "node_type: $node_type\n" if ($self->debug);
    }

    if ($node->has_tag("E")) {
        my $n_lost = $node->get_tagvalue("E");
        $n_lost =~ s/.{2}//;        # get rid of the initial $-
        my @lost_taxa = split('-', $n_lost);
        my $topup = 0;   # is used to delete all the pre-existing lost_taxon_id
        foreach my $taxon (@lost_taxa) {
            print "lost_taxon_id : $taxon\n" if ($self->debug);
            $node->store_tag('lost_taxon_id', $taxon, $topup);
            $topup = 1;
        }
    }

    if ($node->has_tag('T') and $self->param('store_tree_support')) {
        my $binary_support = $node->get_tagvalue('T');
        my $i = 0;
        my $topup = 0;   # is used to delete all the pre-existing tree_support
        while ($binary_support) {
            if ($binary_support & 1) {
                print 'tree_support : ', $ref_support->[$i], "\n" if ($self->debug);
                $node->store_tag('tree_support', $ref_support->[$i], $topup);
                $topup = 1;
            }
            $binary_support >>= 1;
            $i++;
        }
    }

    my %mapped_tags = ('B' => 'bootstrap', 'SIS' => 'species_intersection_score', 'S' => 'treebest_taxon_id');
    foreach my $tag (keys %mapped_tags) {
        next unless $node->has_tag($tag);
        my $value = $node->get_tagvalue($tag);
        my $db_tag = $mapped_tags{$tag};

        $node->store_tag($db_tag, $value);
        print "$tag as $db_tag: $value\n" if ($self->debug);
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
    $leaves{$node->member_id} = $node;
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
        $newnode->add_tag('T', $othernode->get_tagvalue('T'));
        $othernode->remove_tag('T');
        $newnode->print_tree(10) if $self->debug;
    }
  }
  print  "Tree after split_genes insertions:\n";
  $newroot->print_tree(20) if($self->debug > 1);

  # get rid of the taxon_id needed by njtree -- name tag
  foreach my $leaf (@{$newroot->get_all_leaves}) {
    my $njtree_phyml_name = $leaf->get_tagvalue('name');
    $njtree_phyml_name =~ /(\d+)\_\d+/;
    my $member_id = $1;
    my $old_leaf = $leaves{$member_id};
    if (not $old_leaf) {
      $leaf->print_node;
      die "unable to find member '$member_id' (in '$njtree_phyml_name', from newick '$newick')";
    }
    bless $leaf, 'Bio::EnsEMBL::Compara::GeneTreeMember';
    $leaf->member_id($member_id);
    $leaf->gene_member_id($old_leaf->gene_member_id);
    $leaf->cigar_line($old_leaf->cigar_line);
    $leaf->node_id($old_leaf->node_id);
    $leaf->taxon_id($old_leaf->taxon_id);
    $leaf->stable_id($old_leaf->stable_id);
    $leaf->adaptor($old_leaf->adaptor);
    $leaf->add_tag('name', $member_id);
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
    $clusterset->adaptor->db->get_GeneTreeNodeAdaptor->store_nodes_rec($clusterset_leaf);

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
            $member->stable_id($self->_name_for_prot($member));
            $member->{'_children_loaded'} = 1;
        }
        $newtree->ref_root_id($tree->root_id);
        $self->store_tree_into_clusterset($newtree, $clusterset);
        ${$self->param('other_trees')}{$clusterset->clusterset_id} = $newtree;
    }

    return ${$self->param('other_trees')}{$clusterset->clusterset_id};
}

sub store_alternative_tree {
    my ($self, $newick, $clusterset_id, $ref_tree) = @_;
    my $clusterset = $self->compara_dba->get_GeneTreeAdaptor->fetch_all(-tree_type => 'clusterset', -clusterset_id => $clusterset_id)->[0];
    if (not defined $clusterset) {
        $self->throw("The clusterset_id '$clusterset_id' is not defined. Cannot store the alternative tree");
        return;
    }
    my $newtree = $self->fetch_or_create_other_tree($clusterset, $ref_tree);
    $self->parse_newick_into_tree($newick, $newtree);
    $self->store_genetree($newtree);
    $newtree->release_tree;
    return $newtree;
}



1;
