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

sub method_link_species_set_id {
    my ($self, $mlss_id) = @_;
    if (defined $mlss_id) {
        $self->{'_method_link_species_set_id'} = $mlss_id;
    }
    return $self->{'_method_link_species_set_id'};
}

sub species_tree {
    my ($self, $species_tree) = @_;
    if (defined $species_tree) {
        $self->{'_species_tree'} = $species_tree;
    }
    return $self->{'_species_tree'};
}

sub lambdas {
    my ($self, $lambdas) = @_;
    if (defined $lambdas) {
        $self->{'_lambdas'} = $lambdas;
    }
    return $self->{'_lambdas'};
}

sub pvalue_avg {
    my ($self, $pvalue_avg) = @_;
    if (defined $pvalue_avg) {
        $self->{'_pvalue_avg'} = $pvalue_avg;
    }
    return $self->{'_pvalue_avg'};
}

sub pvalue_lim {
    my ($self, $pvalue_lim) = @_;
    if (defined $pvalue_lim) {
        $self->{'_pvalue_lim'} = $pvalue_lim;
    }
    return $self->{'_pvalue_lim'};
}

sub lca_id {
    my ($self, $lca_id) = @_;
    if (defined $lca_id) {
        $self->{'_lca_id'} = $lca_id;
    }
    return $self->{'_lca_id'};
}

sub gene_tree_root_id {
    my ($self, $gene_tree_root_id) = @_;
    if (defined $gene_tree_root_id) {
        $self->{'_gene_tree_root_id'} = $gene_tree_root_id;
    }
    return $self->{'_gene_tree_root_id'};
}

sub taxon_id {
    my ($self, $taxon_id) = @_;
    if (defined $taxon_id) {
        $self->{'_taxon_id'} = $taxon_id;
    }
    return $self->{'_taxon_id'};
}

sub n_members {
    my ($self, $n_members) = @_;
    if (defined $n_members) {
        $self->{'_n_members'} = $n_members;
    }
    return $self->{'_n_members'};
}

sub pvalue {
    my ($self, $pvalue) = @_;
    if (defined $pvalue) {
        $self->{'_pvalue'} = $pvalue;
    }
    return $self->{'_pvalue'};
}

sub cafe_gene_family_id {
    my ($self, $cafe_gene_family_id) = @_;
    if (defined $cafe_gene_family_id) {
        $self->{'_cafe_gene_family_id'} = $cafe_gene_family_id;
    }
    return $self->{'_cafe_gene_family_id'};
}

sub is_tree_significant {
    my ($self) = @_;
    return $self->pvalue_avg < $self->pvalue_lim;
}

sub is_node_significant {
    my ($self) = @_;
    return $self->pvalue < $self->pvalue_lim;
}

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

sub is_expansion {
    my ($self) = @_;
    if ($self->has_parent) {
        return 1 if ($self->n_members > $self->parent->n_members);
    }
    return 0;
}

sub is_contraction {
    my ($self) = @_;
    if ($self->has_parent) {
        return 1 if ($self->n_members < $self->parent->n_members);
    }
    return 0;
}

#################################


sub genome_db {
    my ($self) = @_;
    return undef unless ($self->is_leaf);
    $self->throw("taxon_id is not set in this node") unless ($self->taxon_id);
    my $genomeDBAdaptor = $self->adaptor->db->get_GenomeDBAdaptor;
    my $genomeDB = $genomeDBAdaptor->fetch_by_taxon_id($self->taxon_id);
    return $genomeDB;
}

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

sub lca_taxon_id {
    my ($self) = @_;
    my $lca_id = $self->lca_id;
    my $sth = $self->adaptor->prepare("SELECT value FROM species_tree_node_tag WHERE node_id = ? AND tag = 'taxon_id'");
    $sth->execute($lca_id);
    my ($taxon_id) = $sth->fetchrow_array();
    return $taxon_id;
}

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
