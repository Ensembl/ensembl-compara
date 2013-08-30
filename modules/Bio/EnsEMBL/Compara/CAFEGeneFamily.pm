=head1 LICENSE

  Copyright (c) 2012-2013 The European Bioinformatics Institute and
  Genome Research Limited. All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

  http://www.ensembl.org/info/about/code_license.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>

=head1 NAME

Bio::EnsEMBL::Compara::CAFEGeneFamily

=head1 SYNOPSIS


=head1 DESCRIPTION

Specific subclass of the NestedSet to handle CAFE trees

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::CAFEGeneFamily
  +- Bio::EnsEMBL::Compara::NestedSet

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with an underscore (_).

=cut

package Bio::EnsEMBL::Compara::CAFEGeneFamily;

use strict;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::NestedSet');

######################################################
#
# Object variable methods
#
######################################################

=head2 method_link_species_set_id

    Arg[1]      : (opt.) int
    Example     : my $mlss_id = $tree->method_link_species_set_id
    Description : Getter/Setter for the method_link_species_set associated with this analysis
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub method_link_species_set_id {
    my ($self, $mlss_id) = @_;
    if (defined $mlss_id) {
        $self->{'_method_link_species_set_id'} = $mlss_id;
    }
    return $self->{'_method_link_species_set_id'};
}

=head2 species_tree

    Arg[1]      : (opt.) <string> The species tree in newick format
    Example     : my $newick_tree = $tree->species_tree
    Description : Getter/Setter for the species tree in newick format
    ReturnType  : string
    Exceptions  : none
    Caller      : general

=cut

sub species_tree {
    my ($self, $species_tree) = @_;
    if (defined $species_tree) {
        $self->{'_species_tree'} = $species_tree;
    }
    return $self->{'_species_tree'};
}

=head2 multifurcate_tree

    Arg[1]      : -none-
    Example     : $tree->multifurcate_tree
    Description : Removes redundant nodes of a gene gain/loss tree
                  restoring original branch lengths.
                  These redundant nodes are originated during the CAFE analysis,
                  where a binary, ultrametric tree is needed instead of the original one
                  with multi-furcated nodes
    ReturnType  : undef (The object is updated)
    Exceptions  : none
    Caller      : general

=cut

sub multifurcate_tree {
    my ($self) = @_;

    my $NCBItaxon_Adaptor = $self->adaptor->db->get_NCBITaxon();
    for my $node (@{$self->get_all_nodes}) {
        next unless (defined $node->parent);
        my $ncbiTaxon = $NCBItaxon_Adaptor->fetch_node_by_taxon_id($node->taxon_id);
        my $mya = $ncbiTaxon->get_tagvalue('ensembl timetree mya') || 0;
        for my $child (@{$node->children()}) {
            $child->distance_to_parent(int($mya));
        }
#        $node->distance_to_parent($mya);
        if ($node->taxon_id eq $node->parent->taxon_id) {
            $node->parent->merge_children($node);
            $node->parent->remove_nodes([$node]);
        }
    }
}

=head2 lambdas

    Arg[1]      : (opt.) <double> The lambda(s) obtained during the CAFE analysis
    Example     : my $lambdas = $tree->lambdas
    Description : Getter/Setter for the lambda(s) obtained in the analysis
    ReturnType  : scalar. The string (newick) representation of the tree
    Exceptions  : none
    Caller      : general

=cut

sub lambdas {
    my ($self, $lambdas) = @_;
    if (defined $lambdas) {
        $self->{'_lambdas'} = $lambdas;
    }
    return $self->{'_lambdas'};
}

=head2 pvalue_avg

    Arg[1]      : (opt.) <double> p-value
    Example     : my $avg_pvalue = $tree->pvalue_avg
    Description : Getter/Setter for the average p-value of the family as reported by CAFE
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub pvalue_avg {
    my ($self, $pvalue_avg) = @_;
    if (defined $pvalue_avg) {
        $self->{'_pvalue_avg'} = $pvalue_avg;
    }
    return $self->{'_pvalue_avg'};
}

=head2 pvalue_lim

    Arg[1]      : (opt.) <double> p-value
    Example     : my $pvalue_lim = $tree->pvalue_lim
    Description : Getter/Setter for the p-value limit
                  (to consider a gene gain/loss significant)
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub pvalue_lim {
    my ($self, $pvalue_lim) = @_;
    if (defined $pvalue_lim) {
        $self->{'_pvalue_lim'} = $pvalue_lim;
    }
    return $self->{'_pvalue_lim'};
}


=head2 lca_id

    Arg[1]      : (opt.) <int> taxonomy id
    Example     : my $lca = $tree->lca_id
    Description : Getter/Setter for the lowest common ancestor's taxonomy ID
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub lca_id {
    my ($self, $lca_id) = @_;
    if (defined $lca_id) {
        $self->{'_lca_id'} = $lca_id;
    }
    return $self->{'_lca_id'};
}

=head2 gene_tree_root_id

    Arg[1]      : (opt.) <int> Internal ID
    Example     : my $root_id = $tree->gene_tree_root_id
    Description : Getter/Setter for the root ID of the associated gene tree
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub gene_tree_root_id {
    my ($self, $gene_tree_root_id) = @_;
    if (defined $gene_tree_root_id) {
        $self->{'_gene_tree_root_id'} = $gene_tree_root_id;
    }
    return $self->{'_gene_tree_root_id'};
}

=head2 taxon_id

    Arg[1]      : (opt.) <int> Taxon ID
    Example     : my $taxon_id = $tree->taxon_id
    Description : Getter/Setter for the taxon_id of the node
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub taxon_id {
    my ($self, $taxon_id) = @_;
    if (defined $taxon_id) {
        $self->{'_taxon_id'} = $taxon_id;
    }
    return $self->{'_taxon_id'};
}

=head2 n_members

    Arg[1]      : (opt.) <int>
    Example     : my $n_members = $tree->n_memberse
    Description : Getter/Setter for the number of members in the node
                  (gene counts for leaves and CAFE-estimated counts for internal nodes)
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub n_members {
    my ($self, $n_members) = @_;
    if (defined $n_members) {
        $self->{'_n_members'} = $n_members;
    }
    return $self->{'_n_members'};
}

=head2 pvalue

    Arg[1]      : (opt.) <double> pvalue
    Example     : my $pvalue = $tree->pvalue
    Description : Getter/Setter for the pvalue of having an expansion or contraction
                  in the node
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub pvalue {
    my ($self, $pvalue) = @_;
    if (defined $pvalue) {
        $self->{'_pvalue'} = $pvalue;
    }
    return $self->{'_pvalue'};
}


=head2 cafe_gene_family_id

    Arg[1]      : (opt.) <int> ID
    Example     : my $gene_family_id = $tree->cafe_gene_family_id
    Description : Getter/Setter for the internal ID of the gene family
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub cafe_gene_family_id {
    my ($self, $cafe_gene_family_id) = @_;
    if (defined $cafe_gene_family_id) {
        $self->{'_cafe_gene_family_id'} = $cafe_gene_family_id;
    }
    return $self->{'_cafe_gene_family_id'};
}

=head2 is_tree_significant

    Arg[1]      : -none-
    Example     : if ($tree->is_gene_significant) {#do something with gene family}
    Description : Returns if the gene family has a significant expansion or contraction
    ReturnType  : 0/1 (false/true)
    Exceptions  : none
    Caller      : general

=cut

sub is_tree_significant {
    my ($self) = @_;
    return $self->pvalue_avg < $self->pvalue_lim;
}

=head2 is_node_significant

    Arg[1]      : -none-
    Example     : if ($node->is_node_significant) {#do something with the node}
    Description : Returns if the node has a significant expansion or contraction
    ReturnType  : 0/1 (false/true)
    Exceptions  : none
    Caller      : general

=cut

sub is_node_significant {
    my ($self) = @_;
    return $self->pvalue < $self->pvalue_lim;
}


=head2 get_contractions

    Arg[1]      : -none-
    Example     : my $contractions = $tree->get_contractions();
    Description : Returns all the significant contractions present in the given gene family
    ReturnType  : An arrayref of Bio::EnsEMBL::Compara::CAFEGeneFamily objects
    Exceptions  : none
    Caller      : general

=cut

sub get_contractions {
    my ($self) = @_;
    my $contractions = [];
    for my $node (@{$self->get_all_nodes}) {
        if (defined $node->pvalue && ($node->pvalue < $self->pvalue_lim) && $node->is_contraction) {
            push @{$contractions}, $node;
        }
    }
    return $contractions;
}

=head2 get_expansions

    Arg[1]      : -none-
    Example     : my $expansions = $tree->get_expansions();
    Description : Returns all the significant expansions present in the given gene family
    ReturnType  : An arrayref of Bio::EnsEMBL::Compara::CAFEGeneFamily objects
    Exceptions  : none
    Caller      : general

=cut

sub get_expansions {
    my ($self) = @_;
    my $expansions = [];
    for my $node (@{$self->get_all_nodes}) {
        if (defined $node->pvalue && ($node->pvalue < $self->pvalue_lim) && $node->is_expansion) {
            push @{$expansions}, $node;
        }
    }
    return $expansions;
}


=head2 is_expansion

    Arg[1]      : -none-
    Example     : if($node->is_expansion) {#do something with node}
    Description : Returns if a given gene family has been expanded in this node
                  of the species tree even if the expansion is not significant
                  (i.e. only compares the number or members of the nodes with its parent)
    ReturnType  : 0/1 (false/true)
    Exceptions  : none
    Caller      : general

=cut

sub is_expansion {
    my ($self) = @_;
    if ($self->has_parent) {
        return $self->parent->is_expansion if ($self->is_node_significant && ($self->n_members == $self->parent->n_members));
        return 1 if ($self->n_members > $self->parent->n_members);
    }
    return 0;
}


=head2 is_contraction

    Arg[1]      : -none-
    Example     : if($node->is_contraction) {#do something with node}
    Description : Returns if a given gene family has been contracted in this node
                  of the species tree even if the contraction is not significant
                  (i.e. only compares the number or members of the nodes with its parent)
    ReturnType  : 0/1 (false/true)
    Exceptions  : none
    Caller      : general

=cut

sub is_contraction {
    my ($self) = @_;
    if ($self->has_parent) {
        return $self->parent->is_contraction if ($self->is_node_significant && ($self->n_members == $self->parent->n_members));
        return 1 if ($self->n_members < $self->parent->n_members);
    }
    return 0;
}

#################################

=head2 genome_db

    Arg[1]      : -none-
    Example     : my $genome_db = $tree->genome_db
    Description : Returns the genome db object corresponding to the given leaf of the tree
    ReturnType  : Bio::EnsEMBL::Compara::GenomeDB
    Exceptions  : none
    Caller      : general

=cut

sub genome_db {
    my ($self) = @_;
    return undef unless ($self->is_leaf);
    $self->throw("taxon_id is not set in this node") unless ($self->taxon_id);
    my $genomeDBAdaptor = $self->adaptor->db->get_GenomeDBAdaptor;
    my $genomeDB = $genomeDBAdaptor->fetch_by_taxon_id($self->taxon_id);
    return $genomeDB;
}


=head2 get_leaf_with_genome_db_id

    Arg[1]      : <int> ID
    Example     : my $leaf = $tree->get_leaf_with_genome_db_id($genome_db_id);
    Description : Returns the leaf having the requested genome_db_id
    ReturnType  : Bio::EnsEMBL::Compara::CAFEGeneFamily
    Exceptions  : none
    Caller      : general

=cut

sub get_leaf_with_genome_db_id {
    my ($self, $genome_db_id) = @_;

    $self->throw("genome_db_id is not set") unless (defined $genome_db_id);
    my $GenomeDBAdaptor = $self->adaptor->get_GenomeDBAdaptor;
    my $genomeDB = $GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
    my $taxon_id = $genomeDB->taxon_id();
    my $node;
    for my $leaf (@{$self->get_all_leaves}) {
        if ($leaf->taxon_id == $taxon_id) {
            $node = $leaf;
            last;
        }
    }
    return $node;
}


=head2 lca_taxon_id

    Arg[1]      : -none-
    Example     : my $taxon_id = $tree->lca_taxon_id
    Description : Returns the taxon_id of the lowest common ancestor of the tree
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub lca_taxon_id {
    my ($self) = @_;
    my $lca_id = $self->lca_id;
    my $sth = $self->adaptor->prepare("SELECT value FROM species_tree_node_tag WHERE node_id = ? AND tag = 'taxon_id'");
    $sth->execute($lca_id);
    my ($taxon_id) = $sth->fetchrow_array();
    return $taxon_id;
}


=head2 lca_reroot

    Arg[1]      : -none-
    Example     : my $lca_tree = $tree->lca_reroot
    Description : Returns the lowest common ancestor of the tree
    ReturnType  : Bio::EnsEMBL::Compara::CAFEGeneFamily
    Exceptions  : none
    Caller      : general

=cut

sub lca_reroot {
    my ($self) = @_;
    my $lca_id = $self->lca_id();
    for my $node (@{$self->get_all_nodes}) {
        if ($node->node_id == $lca_id) {
            my $lca_tree = $self->adaptor->fetch_lca_tree($node);
            return $lca_tree;
        }
    }
    $self->throw("Problem getting re-rooting the tree by lca");
}

1;
