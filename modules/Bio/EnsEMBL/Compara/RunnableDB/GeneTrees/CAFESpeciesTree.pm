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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CAFESpeciesTree

=head1 SYNOPSIS

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
use Data::Dumper;
use Scalar::Util qw(looks_like_number);
use Bio::EnsEMBL::Compara::Graph::NewickParser;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
            'tree_fmt' => '%{n}%{":"d}',
            'pvalue_lim' => 0.01,
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

    my $genomeDB_Adaptor = $self->compara_dba->get_GenomeDBAdaptor();
    $self->param('genomeDB_Adaptor', $genomeDB_Adaptor);

    my $NCBItaxon_Adaptor = $self->compara_dba->get_NCBITaxon(); # Adaptor??
    $self->param('NCBItaxon_Adaptor', $NCBItaxon_Adaptor);

    my $CAFETree_Adaptor = $self->compara_dba->get_CAFEGeneFamilyAdaptor();
    $self->param('cafeTree_Adaptor', $CAFETree_Adaptor);
    print STDERR $CAFETree_Adaptor;

    my $species_tree_meta_key = $self->param('species_tree_meta_key');

    my $full_species_tree = $self->get_species_tree_string($species_tree_meta_key);
    $self->param('full_species_tree', $full_species_tree);

    $self->param('tree_fmt', '%{n}%{":"d}'); # format for the tree

    die "mlss_id is an obligatory parameter\n" unless (defined $self->param('mlss_id'));

    my $cafe_species = $self->param('cafe_species');
    if ((not defined $cafe_species) or ($cafe_species eq '') or (scalar(@{$cafe_species}) == 0)) {  # No species for the tree. Make a full tree
#        die "No species for the CAFE tree";
        print STDERR "No species provided for the CAFE tree. I will take them all\n" if ($self->debug());
        $self->param('cafe_species', undef);
    }

    return;
}

sub run {
    my ($self) = @_;
    my $species_tree_string = $self->param('full_species_tree');
    my $species = $self->param('cafe_species');
    my $fmt = $self->param('tree_fmt');
    my $mlss_id = $self->param('mlss_id');
    my $pvalue_lim = $self->param('pvalue_lim');
    print STDERR Dumper $species if ($self->debug());
    my $eval_species_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($species_tree_string);

    $self->include_distance_to_parent($eval_species_tree);
    print STDERR "AFTER dtp:\n", $eval_species_tree->newick_format('ryo', $fmt), "\n" if ($self->debug());
    $self->fix_ensembl_timetree_mya($eval_species_tree);
    print STDERR "AFTER fix_mya:\n", $eval_species_tree->newick_format('ryo', $fmt), "\n" if ($self->debug());
    $self->ensembl_timetree_mya_to_distance_to_parent($eval_species_tree);
    print STDERR "AFTER mya:\n", $eval_species_tree->newick_format('ryo', $fmt), "\n" if ($self->debug());
    $self->include_names($eval_species_tree);
    print STDERR "AFTER names:\n", $eval_species_tree->newick_format('ryo', $fmt), "\n" if ($self->debug());
    $self->ultrametrize($eval_species_tree);
    print STDERR "AFTER ultrametrize:\n", $eval_species_tree->newick_format('ryo', $fmt), "\n" if ($self->debug());
    my $binTree = $self->binarize($eval_species_tree);
    print STDERR "AFTER binarize:\n", $binTree->newick_format('ryo', $fmt), "\n" if ($self->debug());
    $self->fix_zeros($binTree);
    print STDERR "AFTER fixing the zeros:\n", $binTree->newick_format('ryo', $fmt), "\n" if ($self->debug());
    my $cafeTree;
    if (defined $species) {
        print STDERR "The tree is going to be pruned\n" if ($self->debug());
        $cafeTree = $self->prune_tree($binTree, $species);
    } else {
        print STDERR "The tree is NOT going to be pruned\n" if ($self->debug());
        $cafeTree = $binTree;
    }
#     if ($self->debug) {
#         $self->check_tree($cafeTree);
#     }


    # Store the tree
    my $cafeTree_Adaptor = $self->param('cafeTree_Adaptor');
    my $cafeTreeStr = $cafeTree->newick_format('ryo', $fmt);
    print STDERR "Tree to store:\n$cafeTreeStr\n" if ($self->debug);

    # The tree is inserted in the method_link_species_set_tag table
    my $sql = "INSERT INTO method_link_species_set_tag VALUES(?,?,?)";
    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute($mlss_id, 'cafe_tree_string', $cafeTreeStr);
    $sth->finish;

    # The tree is stored as a CAFEGeneFamily
    my $tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree($cafeTreeStr, 'Bio::EnsEMBL::Compara::CAFEGeneFamily');
    $tree->species_tree($cafeTreeStr);
    $tree->pvalue_lim($pvalue_lim);
    $tree->method_link_species_set_id($mlss_id);
    $cafeTree_Adaptor->store_tree($tree);
}

sub write_output {
    my ($self) = @_;
    # To CAFETable
    $self->dataflow_output_id (
                               {
                                'cafe_tree_string_meta_key', $self->param('cafe_tree_string_meta_key'),
                               }, 1
                              );
}


#############################
## Internal methods #########
#############################

sub get_species_tree_string {
    my ($self, $species_tree_meta_key) = @_;

    my $table_name = 'meta';
    my $table_key = 'meta_key';
    my $table_column = 'meta_value';
    my $table_value = $species_tree_meta_key;

    my $sth = $self->compara_dba->dbc->prepare( "select $table_column from $table_name where $table_key=?" );
    $sth->execute($table_value);
    my ($species_tree_string) = $sth->fetchrow_array;
    $sth->finish;
    return $species_tree_string;
}

sub get_taxon_id_from_dbID {
    my ($self, $dbID) = @_;
    my $genomeDB_Adaptor = $self->param('genomeDB_Adaptor');
    my $genomeDB = $genomeDB_Adaptor->fetch_by_dbID($dbID);
    return $genomeDB->taxon_id();
}


sub is_in {
    my ($item, $arref) = @_;
    for my $elem (@$arref) {
        if ($item eq $elem) {
            return 1;
        }
    }
    return 0;
}

sub include_distance_to_parent {
    my ($self, $tree) = @_;
    my $NCBItaxon_Adaptor = $self->param('NCBItaxon_Adaptor');

    my $nodes = $tree->get_all_nodes();
    for my $node (@$nodes) {
        unless ($node->is_leaf) {
            my $taxon_id = $node->name();
            my $ncbiTaxon = $NCBItaxon_Adaptor->fetch_node_by_taxon_id($taxon_id);
            my $mya = $ncbiTaxon->get_tagvalue('ensembl timetree mya');
            for my $child (@{$node->children}) {
                if ($mya) {
                    $child->distance_to_parent(int($mya));
                } else {
                    print STDERR "++ taxon_id " . $child->name() . " doesn't have 'ensembl timetree mya' tag (defaulting to 0)\n" if ($self->debug);
                    $child->distance_to_parent(0);
                }
            }
        }
    }
}

sub fix_ensembl_timetree_mya {
    my ($self, $tree) = @_;
    my $leaves = $tree->get_all_leaves();
    for my $leaf (@$leaves) {
        fix_path($leaf);
    }
}

sub fix_path {
    my ($node) = @_;
    for (;;) {
        if ($node->has_parent()) {
            if ($node->parent->distance_to_parent() == 0) {
                $node = $node->parent;
                next;
            }
            if ($node->parent()->distance_to_parent() < $node->distance_to_parent()) {
                $node->distance_to_parent($node->parent()->distance_to_parent());
            }
        } else {
            return
        }
        $node = $node->parent();
    }
}

sub ensembl_timetree_mya_to_distance_to_parent {
    my ($self, $tree) = @_;
    my $leaves = $tree->get_all_leaves();
    for my $leaf (@$leaves) {
        mya_to_dtp_1path($leaf);
    }
}

sub mya_to_dtp_1path {
    my ($node) = @_;
    my $d = 0;
    for (;;) {
        my $dtp = 0;
        if ($node->get_tagvalue('revised') eq 1) {
            if ($node->has_parent()) {
                $node = $node->parent();
                next;
            } else {
                return;
            }
        }
        if ($node->distance_to_parent != 0) {
            $dtp = $node->distance_to_parent - $d;
        }
        $node->distance_to_parent($dtp);
        $node->add_tag("revised", "1");
        $d += $dtp;
        if ($node->has_parent()) {
            $node = $node->parent();
        } else {
            return;
        }
    }
}

sub include_names {
    my ($self, $tree) = @_;
    my $genomeDB_Adaptor = $self->param('genomeDB_Adaptor');
    my $leaves = $tree->get_all_leaves();
    for my $leaf ( @$leaves ) {
        my $taxon_id = $leaf->name();
        $taxon_id =~ s/\*//g;
        my $genomeDB = $genomeDB_Adaptor->fetch_by_taxon_id($taxon_id);
        my $name = $genomeDB->name();
        $name =~ s/_/\./g;
        $leaf->name($name);
    }
}

sub ultrametrize {
    my ($self, $tree) = @_;
    my $longest_path = get_longest_path($tree);
    my $leaves = $tree->get_all_leaves();
    for my $leaf (@$leaves) {
        my $path = path_length($leaf);
        $leaf->distance_to_parent($leaf->distance_to_parent() + ($longest_path-$path));
    }
}

sub get_longest_path {
    my ($tree) = @_;
    my $leaves = $tree->get_all_leaves();
    my @paths;
    my $longest = -1;
    for my $leaf(@$leaves) {
        my $newpath = path_length($leaf);
        if ($newpath > $longest) {
            $longest = $newpath;
        }
    }
    return $longest;
}

sub binarize {
    my ($self, $orig_tree) = @_;
    my $newTree = Bio::EnsEMBL::Compara::NestedSet->new();
    $newTree->name('root');
    $newTree->node_id('0');
    _binarize($orig_tree, $newTree);
    return $newTree;
}

sub _binarize {
    my ($origTree, $binTree) = @_;
    my $children = $origTree->children();
    for my $child (@$children) {
        my $newNode = Bio::EnsEMBL::Compara::NestedSet->new();
        $newNode->name($child->name());
        $newNode->node_id($child->node_id());
        $newNode->distance_to_parent($child->distance_to_parent()); # no parent!!
        if (scalar @{$binTree->children()} > 1) {
            $child->disavow_parent();
            my $newBranch = Bio::EnsEMBL::Compara::NestedSet->new();
            for my $c (@{$binTree->children()}) {
                $c->distance_to_parent(0);
                $newBranch->add_child($c);
            }
            $binTree->add_child($newBranch);
            $newBranch->name($newBranch->parent()->name());
        }
        $binTree->add_child($newNode);
        _binarize($child, $newNode);
    }
}

sub fix_zeros {
    my ($self, $tree) = @_;
    my $leaves = $tree->get_all_leaves();
    for my $leaf (@$leaves) {
        fix_zeros_1($leaf);
    }
}

sub fix_zeros_1 {
    my ($node) = @_;
    my $to_add = 0;
    for (;;) {
        return unless ($node->has_parent());
        my $dtp = $node->distance_to_parent();
        if ($dtp == 0) {
            $to_add++;
            $node->distance_to_parent(1);
        }
        my $siblings = siblings($node);
        die "too many siblings" if (scalar @$siblings > 1);
        $siblings->[0]->distance_to_parent($siblings->[0]->distance_to_parent() + $to_add);
        $node = $node->parent();
    }
}

sub prune_tree {
    my ($self, $tree, $species_to_keep) = @_;
    my $leaves = $tree->get_all_leaves();
    my %species_to_remove;
    for my $leaf (@$leaves) {
        my $name = $leaf->name();
        $species_to_remove{$name} = 1;
    }
    for my $sp (@$species_to_keep) {
        delete $species_to_remove{$sp};
    }
    my $newTree = remove_nodes($tree, [keys %species_to_remove]);
    return $newTree;
}

sub remove_nodes {
    my ($tree, $nodes) = @_;
    my $leaves = $tree->get_all_leaves();
    for my $node (@$leaves) {
        if (is_in($node->name, $nodes)) {
            if ($node->has_parent()) {
                my $parent = $node->parent();
                my $siblings = siblings($node);
                if (scalar @$siblings > 1) {
                    die "The tree is not binary";
                }
                $node->disavow_parent();
                if ($parent->has_parent) {
                    my $grandpa = $parent->parent();
                    my $dtg = $parent->distance_to_parent();
                    $parent->disavow_parent();
                    my $newsdtp = $siblings->[0]->distance_to_parent() + $dtg;
                    $grandpa->add_child($siblings->[0], $newsdtp);
                } else {
                    $siblings->[0]->disavow_parent();
                    $tree=$siblings->[0];
                }
            }
        }
    }
    return $tree;
}

sub siblings {
    my ($node) = @_;
    return undef unless ($node->has_parent());
    my $parent = $node->parent();
    my $children = $parent->children();
    my @siblings = ();
    for my $child (@$children) {
        if ($child != $node) {
            push @siblings, $child;
        }
    }
    return [@siblings];
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

  eval (is_binary($tree));
  if ($@) {
    die $@;
  } else {
      if ($self->debug()) {
          print STDERR "The tree is binary\n";
      }
  }
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
    if ($path == $newpath) {
      $path = $newpath;
    } else {
      return 0
    }
  }
  return 1
}

sub path_length {
  my ($node) = @_;
  my $d = 0;
  for (;;){
    $d += $node->distance_to_parent();
    if ($node->has_parent()) {
      $node = $node->parent();
    } else {
      last;
    }
  }
  return $d;
}

1;
