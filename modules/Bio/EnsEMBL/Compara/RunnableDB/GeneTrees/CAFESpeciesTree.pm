=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFESpeciesTree

=head1 DESCRIPTION

This RunnableDB builds a CAFE-compliant species tree (binary & ultrametric with time units).

=head1 INHERITANCE TREE

Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFESpeciesTree;

use strict;
use warnings;

use Data::Dumper;

use Bio::EnsEMBL::Compara::Utils::SpeciesTree;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            'label'      => 'full_species_tree',
            'new_label'  => 'cafe',
            'use_genetrees' => 0,
            'use_timetree'  => 1,
           };
}


=head2 fetch_input

    Title     : fetch_input
    Usage     : $self->fetch_input
    Function  : Fetches input data from database
    Returns   : none
    Args      : none

=cut

sub fetch_input {
    my ($self) = @_;

    # Get the species-tree and make a copy to work on it
    my $full_species_tree = $self->compara_dba->get_SpeciesTreeAdaptor->fetch_by_method_link_species_set_id_label($self->param_required('mlss_id'), $self->param('label'));
    $full_species_tree->root( $full_species_tree->root->copy(undef, $self->compara_dba->get_SpeciesTreeNodeAdaptor) );
    $self->param('full_species_tree', $full_species_tree); ## This is the full tree, not the string

    my $cafe_species = $self->param('cafe_species') || [];
    if (not ref($cafe_species)) {
        my $cafe_species_str = $self->param('cafe_species');
        $cafe_species_str =~ s/["'\[\] ]//g;
        $cafe_species = [split(',', $cafe_species_str)];
    }
    if (scalar(@{$cafe_species}) == 0) {  # No species for the tree. Make a full tree
        print STDERR "No species provided for the CAFE tree. I will take them all\n" if ($self->debug());
        $self->param('cafe_species', undef);
        $self->param('n_missing_species_in_tree', 0);
    } else {
        my $genomeDB_Adaptor = $self->compara_dba->get_GenomeDBAdaptor();
        my %gdb_ids = map {$_->dbID => 1} map {$genomeDB_Adaptor->fetch_by_name_assembly($_) || die "Could not find a GenomeDB named '$_'"} @$cafe_species;
        $self->param('cafe_species', \%gdb_ids);
        $self->param('n_missing_species_in_tree', scalar(@{$genomeDB_Adaptor->fetch_all()})-scalar(@{$cafe_species}));
    }

    return;
}

sub run {
    my ($self) = @_;
    my $species_tree = $self->param('full_species_tree');
    my $species_tree_root = $species_tree->root;
    print "INITIAL TREE:\n";
    $species_tree_root->print_tree(0.2);
    my $species = $self->param('cafe_species');
    my $mlss_id = $self->param('mlss_id');
    print STDERR Dumper $species if ($self->debug());

    # Both use_genetrees and use_timetree are wishes that may or may not be
    # fullfilled. In each case, we need to give it a try, and have a
    # fallback method in case it is not possible

    # 1. Use gene-trees to set branch lengths and binarize the multifurcations
    if ($self->param('use_genetrees')) {

        my $all_pt_gene_trees = $self->compara_dba->get_GeneTreeAdaptor->fetch_all(-CLUSTERSET_ID => 'default', -TREE_TYPE => 'tree', -METHOD_LINK_SPECIES_SET => $mlss_id);
        if (@$all_pt_gene_trees) {
            $_->preload for @$all_pt_gene_trees;
            Bio::EnsEMBL::Compara::Utils::SpeciesTree::set_branch_lengths_from_gene_trees($species_tree_root, $all_pt_gene_trees);
            print "AFTER set_branch_lengths_from_gene_trees:\n";
            $species_tree_root->print_tree(5);
            Bio::EnsEMBL::Compara::Utils::SpeciesTree::binarize_multifurcation_using_gene_trees($_, $all_pt_gene_trees) for @{$species_tree_root->get_all_nodes};
            print "AFTER binarize_multifurcation_using_gene_trees:\n";
            $species_tree_root->print_tree(5);
            $_->release_tree for @$all_pt_gene_trees;
        } else {
            $self->param('use_genetrees', 0);
        }
    }
    $_->node_id(undef) for @{$species_tree_root->get_all_nodes};
    unless ($self->param('use_genetrees')) {
        $_->random_binarize_node for @{$species_tree_root->get_all_nodes};
        $species_tree_root->distance_to_parent(0);                              # NULL would be more accurate
        $_->distance_to_parent(100) for $species_tree_root->get_all_subnodes;   # Convention
        print "AFTER random_binarize_node\n";
        $species_tree_root->print_tree(0.002);
    }

    # 2. Use TimeTree to define divergence times (i.e. get an ultrametric tree)
    if ($self->param('use_timetree')) {
        my $n_nodes_with_timetree = scalar(grep {$_->has_divergence_time} @{$species_tree_root->get_all_nodes});
        if ($n_nodes_with_timetree) {
            Bio::EnsEMBL::Compara::Utils::SpeciesTree::interpolate_timetree($species_tree_root);
            Bio::EnsEMBL::Compara::Utils::SpeciesTree::ultrametrize_from_timetree($species_tree_root);
            print "AFTER ultrametrize_from_timetree:\n";
        } else {
            $self->param('use_timetree', 0);
        }
    }
    unless ($self->param('use_timetree')) {
        Bio::EnsEMBL::Compara::Utils::SpeciesTree::ultrametrize_from_branch_lengths($species_tree_root);
        print "AFTER ultrametrize_from_branch_lengths:\n";
    }
    $species_tree_root->print_tree(0.08);

    my $binTree = $species_tree_root;
    my $cafe_tree_root;
    if (defined $species) {
        $cafe_tree_root = $self->prune_tree($binTree, $species);
    } else {
        $cafe_tree_root = $binTree;
    }
    $cafe_tree_root->distance_to_parent(0); # NULL would be more accurate
    $self->check_tree($cafe_tree_root);
    $cafe_tree_root->build_leftright_indexing();

    ## The modified tree is put back in the species tree object
    $species_tree->root($cafe_tree_root);

    # Store the tree (At this point, it is a species tree not a CAFE tree)

    my $cafe_tree_str = $cafe_tree_root->newick_format('full');
    print STDERR "Tree to store:\n$cafe_tree_str\n" if ($self->debug);

    $species_tree->label($self->param_required('new_label'));
}

sub write_output {
    my ($self) = @_;
    $self->compara_dba->get_SpeciesTreeAdaptor->store($self->param('full_species_tree'));
    $self->dataflow_output_id( {
        'species_tree_root_id' => $self->param('full_species_tree')->root_id,
        'n_missing_species_in_tree' => $self->param('n_missing_species_in_tree'),
    }, 2);
}


#############################
## Internal methods #########
#############################

my $float_zero = 1e-7;

sub prune_tree {
    my ($self, $tree, $species_to_keep) = @_;

    my @nodes_to_remove = grep {!$species_to_keep->{$_->genome_db_id}} @{$tree->get_all_leaves};
    return $tree->remove_nodes(\@nodes_to_remove);
}


sub check_tree {
  my ($self, $tree) = @_;
  if (is_ultrametric($tree)) {
      if ($self->debug()) {
          print STDERR "The tree is ultrametric\n";
      }
  } else {
      die "The tree is NOT ultrametric\n";
  }

  no_zeros($tree);

  is_binary($tree);
  if ($self->debug()) {
    print STDERR "The tree is binary\n";
  }
}

sub no_zeros {
    my ($node) = @_;
    if ($node->has_parent) {
        if ($node->distance_to_parent < $float_zero) {
            die "The tree has a zero branch: ".$node->string_node;
        }
    }
    no_zeros($_) for @{$node->children};
}

sub is_binary {
  my ($node) = @_;
  if ($node->is_leaf()) {
    return 0
  }
  my $children = $node->children();
  if (scalar @$children != 2) {
    my $name = $node->name();
    die "Not binary in node $name\n";
  }
  for my $child (@$children) {
    is_binary($child);
  }
}

sub is_ultrametric {
  my ($tree) = @_;
  my $leaves = $tree->get_all_leaves();
  my $path = -1;
  for my $leaf (@$leaves) {
    my $newpath = path_length($leaf);
    if ($path == -1) {
      $path = $newpath;
      next;
    }
    if (abs($path - $newpath) < $float_zero) {
      $path = $newpath;
    } else {
      return 0
    }
  }
  return 1
}

sub path_length {
  my ($node) = @_;
  print STDERR "PATH LENGTH FOR ", $node->taxon_id;
  my $d = 0;
  for (;;){
    $d += $node->distance_to_parent();
    if ($node->has_parent()) {
      $node = $node->parent();
    } else {
      last;
    }
  }
  print STDERR " IS $d\n";
  return $d;
}

1;
