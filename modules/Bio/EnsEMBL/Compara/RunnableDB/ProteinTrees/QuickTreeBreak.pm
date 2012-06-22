=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::QuickTreeBreak

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take ProteinTree as input.

This must already have a multiple alignment run on it. It uses that
alignment as input into the QuickTree program which then generates a
simple phylogenetic tree to be broken down into 2 pieces.

Google QuickTree to get the latest tar.gz from the Sanger.
Google sreformat to get the sequence reformatter that switches from fasta to stockholm.

input_id/parameters format eg: "{'protein_tree_id'=>1234,'clusterset_id'=>1}"
    protein_tree_id : use 'id' to fetch a cluster from the ProteinTree

=head1 SYNOPSIS

my $db           = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $quicktreebreak = Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::QuickTreeBreak->new
  (
   -db         => $db,
   -input_id   => $input_id,
   -analysis   => $analysis
  );
$quicktreebreak->fetch_input(); #reads from DB
$quicktreebreak->run();
$quicktreebreak->output();
$quicktreebreak->write_output(); #writes to DB

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::QuickTreeBreak;

use strict;

use IO::File;
use File::Basename;
use Time::HiRes qw(time gettimeofday tv_interval);

use Bio::AlignIO;
use Bio::SimpleAlign;

use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::GeneTree;
use Bio::EnsEMBL::Compara::GeneTreeNode;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreTree', 'Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut


sub fetch_input {
    my $self = shift @_;

    $self->check_if_exit_cleanly;

    my $protein_tree_id     = $self->param('protein_tree_id') or die "'protein_tree_id' is an obligatory parameter";
    my $protein_tree        = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID( $protein_tree_id )
                                        or die "Could not fetch protein_tree with protein_tree_id='$protein_tree_id'";
    $self->param('gene_tree', $protein_tree);

    $self->param('mlss_id') or die "'mlss_id' is an obligatory parameter";
}


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs NJTREE PHYML
    Returns :   none
    Args    :   none

=cut


sub run {
    my $self = shift @_;

    $self->check_if_exit_cleanly;
    $self->run_quicktreebreak;
}


=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   stores proteintree
    Returns :   none
    Args    :   none

=cut


sub write_output {
    my $self = shift @_;

    $self->check_if_exit_cleanly;
    $self->store_supertree;
}

sub release_tree {
    my $self       = shift @_;
    my $tree_param = shift @_;

    if(my $root = $self->param($tree_param)) {
        $root->release_tree;
        $self->param($tree_param, undef);
    }
}

sub DESTROY {
    my $self = shift;

    printf("QuickTreeBreak::DESTROY releasing trees\n") if($self->debug);

    $self->param('gene_tree')->release_tree;
    $self->param('max_subtree')->release_tree;

    $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}


##########################################
#
# internal methods
#
##########################################


sub run_quicktreebreak {
  my $self = shift;

  my $starttime = time()*1000;
  my $gene_tree = $self->param('gene_tree');

  $self->param('original_leafcount', scalar(@{$gene_tree->get_all_leaves}) );
  if($self->param('original_leafcount')<3) {
    printf(STDERR "tree cluster %d has <3 proteins - can not build a tree\n", $gene_tree->root_id);
    return;
  }
  my $input_aln = $self->dumpTreeMultipleAlignmentToWorkdir ( $gene_tree->root, 1 );

  my $quicktree_exe = $self->param('quicktree_exe')
        or die "'quicktree_exe' is an obligatory parameter";

  die "Cannot execute '$quicktree_exe'" unless(-x $quicktree_exe);

  my $cmd = $quicktree_exe;
  $cmd .= " -out t -in a";
  $cmd .= " ". $input_aln;

  $self->compara_dba->dbc->disconnect_when_inactive(1);
  print("$cmd\n") if($self->debug);
  open(RUN, "$cmd |") or die "Could not open pipe [$cmd |] for reading : $!";
  my @output = <RUN>;
  close(RUN) or die "Could not close pipe [$cmd |] : $!";
  $self->compara_dba->dbc->disconnect_when_inactive(0);

  my $quicktree_newick_string = '';
  foreach my $line (@output) {
    $line =~ s/\n//;
    $quicktree_newick_string .= $line;
  }

  #parse the tree into the datastucture
  $self->generate_subtrees( $quicktree_newick_string );

  my $runtime = time()*1000-$starttime;
  $gene_tree->store_tag('QuickTreeBreak_runtime_msec', $runtime);
}


########################################################
#
# ProteinTree input/output section
#
########################################################


sub store_supertree {
  my $self = shift;

  my $gene_tree_adaptor = $self->compara_dba->get_GeneTreeAdaptor;
  my $starttime = time();

  $gene_tree_adaptor->store($self->param('original_cluster'));
  $self->param('original_cluster')->root->store_tag('tree_support', 'quicktree');
  $self->param('original_cluster')->root->store_tag('node_type', 'speciation');

  foreach my $cluster (@{$self->param('subclusters')}) {
    my $node_id = $cluster->root_id;

    #calc residue count total
    my $leafcount = scalar(@{$cluster->root->get_all_leaves});
    $cluster->store_tag('gene_count', $leafcount);
    print STDERR "Stored $node_id with $leafcount leaves\n" if ($self->debug);

    # Dataflow clusters
    # This will create a new MSA alignment job for each of the newly generated clusters
    #$self->dataflow_output_id({'protein_tree_id' => $node_id}, 2);
    print STDERR "Created new cluster $node_id\n";
  }
  my $super_align_clusterset = $self->fetch_or_create_clusterset('super-align');
# compara_dba->get_GeneTreeAdaptor->fetch_all(-tree_type => 'clusterset', -clusterset_id => 'super-align')->[0];
  $self->store_tree_into_clusterset($self->param('super_align_tree'), $super_align_clusterset);
  $self->param('super_align_tree')->store_tag('other_tree_root_id', $self->param('protein_tree_id'));
  $self->param('original_cluster')->store_tag('other_tree_root_id', $self->param('super_align_tree')->root_id, 1);
}


sub generate_subtrees {
    my $self                    = shift @_;
    my $quicktree_newick_string = shift @_;

    my $mlss_id = $self->param('mlss_id');
    my $gene_tree = $self->param('gene_tree');
    
    # The tree to hold the super-alignment
    $self->param('super_align_tree', $gene_tree->deep_copy());

  #cleanup old tree structure- 
  #  flatten and reduce to only GeneTreeMember leaves
  $gene_tree->root->flatten_tree;
  $gene_tree->root->print_tree(20) if($self->debug);

  #parse newick into a new tree object structure
  my $newtree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($quicktree_newick_string);
  $newtree->print_tree(20) if($self->debug > 1);
  # get rid of the taxon_id needed by njtree -- name tag
  foreach my $leaf (@{$newtree->get_all_leaves}) {
    my $quicktreebreak_name = $leaf->get_tagvalue('name');
    $quicktreebreak_name =~ /(\d+)\_\d+/;
    my $member_name = $1;
    $leaf->add_tag('name', $member_name);
    bless $leaf, "Bio::EnsEMBL::Compara::GeneTreeMember";
    $leaf->member_id($member_name);
  }

  # Break the tree by immediate children recursively
  my @children;
  my $keep_breaking = 1;
  $self->param('max_subtree', $newtree);
  while ($keep_breaking) {
    @children = @{$self->param('max_subtree')->children};
    my $max_num_leaves = 0;
    foreach my $child (@children) {
      my $num_leaves = scalar(@{$child->get_all_leaves});
      if ($num_leaves > $max_num_leaves) {
        $max_num_leaves = $num_leaves;
        $self->param('max_subtree', $child);
      }
    }
    # Broke down to half, happy with it
    my $proportion = ($max_num_leaves*100/$self->param('original_leafcount') );
    print STDERR "QuickTreeBreak iterate -- $max_num_leaves ($proportion)\n" if ($self->debug);
    if ($proportion <= 50) {
      $keep_breaking = 0;
    }
  }

  my $final_original_num = scalar @{$self->param('gene_tree')->root->get_all_leaves};
  # Creating the supertree structure
  my $supertree_root = $self->param('gene_tree')->root;
  my $supertree = $self->param('gene_tree');;
  $supertree->tree_type('supertree');
  my $supertree_leaf1 = new Bio::EnsEMBL::Compara::GeneTreeNode;
  my $supertree_leaf2 = new Bio::EnsEMBL::Compara::GeneTreeNode;
  $supertree_leaf1->tree($supertree);
  $supertree_leaf2->tree($supertree);

  my $cluster1 = new Bio::EnsEMBL::Compara::GeneTree(
    -tree_type => 'tree',
    -member_type => $supertree->member_type,
    -method_link_species_set_id => $supertree->method_link_species_set_id,
    -clusterset_id => $supertree->clusterset_id,
  );
  
  my $cluster2 = new Bio::EnsEMBL::Compara::GeneTree(
    -tree_type => 'tree',
    -member_type => $supertree->member_type,
    -method_link_species_set_id => $supertree->method_link_species_set_id,
    -clusterset_id => $supertree->clusterset_id,
  );
  
  my $subtree_leaves;
  foreach my $leaf (@{$self->param('max_subtree')->get_all_leaves}) {
    $subtree_leaves->{$leaf->member_id} = 1;
  }
  foreach my $leaf (@{$supertree_root->get_all_leaves}) {
    if (defined $subtree_leaves->{$leaf->member_id}) {
      $cluster1->add_Member($leaf);
    } else {
      $cluster2->add_Member($leaf);
    }
  }
  $supertree_root->add_child($supertree_leaf1, $self->param('max_subtree')->distance_to_parent/2);
  $supertree_root->add_child($supertree_leaf2, $self->param('max_subtree')->distance_to_parent/2);
  $supertree_root->build_leftright_indexing(1);
  
  if ($self->debug) {
    print "SUPERTREE " ;
    $supertree_root->print_tree(20);
    print "CLUSTER1 ";
    $cluster1->root->print_tree(20);
    print "CLUSTER2 ";
    $cluster2->root->print_tree(20);
  }
  $supertree_leaf1->add_child($cluster1->root);
  $supertree_leaf2->add_child($cluster2->root);

  if ($self->debug) {
    print "FINAL STRUCTURE ";
    $supertree->root->print_tree(20);
  }

  $self->param('subclusters', [$cluster1, $cluster2]);

  # Some checks
  my       $final_max_num = scalar @{$cluster1->root->get_all_leaves};
  my $final_remaining_num = scalar @{$cluster2->root->get_all_leaves};

  if(($final_max_num + $final_remaining_num) != $final_original_num) {
    die "Incorrect sum of leaves [$final_max_num + $final_remaining_num != $final_original_num]";
  }

  $self->param('original_cluster', $supertree);
}

1;
