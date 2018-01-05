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
  <http://www.ensembl.org/Help/Contact>

=head1 NAME

Bio::EnsEMBL::Compara::CAFEGeneFamily

=head1 DESCRIPTION

Specific class to handle CAFE trees

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::CAFEGeneFamily

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with an underscore (_).

=cut

package Bio::EnsEMBL::Compara::CAFEGeneFamily;

use strict;
use warnings;

use Data::Dumper;

use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use base ('Bio::EnsEMBL::Compara::SpeciesTree');

######################################################
#
# Object variable methods
#
######################################################


sub new_from_SpeciesTree {
    my ($self, $speciesTree) = @_;

    my $cafeGeneFamily_Adaptor = $speciesTree->adaptor->db->get_CAFEGeneFamilyAdaptor;
    my $cafeGeneFamilyNode_Adaptor = $speciesTree->adaptor->db->get_CAFEGeneFamilyNodeAdaptor;

    my $cafeTree = $self->new();
    $cafeTree->adaptor($cafeGeneFamily_Adaptor);
    $cafeTree->method_link_species_set_id($speciesTree->method_link_species_set_id);
    $cafeTree->label($speciesTree->label);
    $cafeTree->root_id($speciesTree->root_id);

    my $cafe_tree_root = $speciesTree->root->copy('Bio::EnsEMBL::Compara::CAFEGeneFamilyNode', $cafeGeneFamilyNode_Adaptor);
    $cafeTree->root($cafe_tree_root);
    return $cafeTree;
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

=head2 pvalue_lim

    Arg[1]      : none
    Example     : my $pvalue_lim = $tree->pvalue_lim
    Description : Getter for the p-value limit
                  (to consider a gene gain/loss significant)
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub pvalue_lim {
    my ($self) = @_;
    return $self->root->pvalue_lim;
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

=head2 lca_taxon_id

    Arg[1]      : [none]
    Example     : $taxon_id = $species_tree->lca_taxon_id();
    Description : Getter to get the taxon_id of the lca node
    ReturnType  : Scalar
    Exceptions  : none
    Caller      : general

=cut

sub lca_taxon_id {
    my ($self) = @_;

    my $lca_id = $self->lca_id();
    my $lca_node = $self->root->lca_reroot($lca_id);
    return $lca_node->taxon_id;
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


sub root {
    my ($self, $node) = @_;
    ## TODO: Cache root
    if (defined $node) {
        assert_ref($node, 'Bio::EnsEMBL::Compara::CAFEGeneFamilyNode', 'node');
         $self->{'_root'} = $node;
    }

    if (not defined $self->{'_root'}) {
        if (defined $self->cafe_gene_family_id and defined $self->adaptor) {
            my $stn_adaptor = $self->adaptor->db->get_CAFEGeneFamilyNodeAdaptor;
            $self->{'_root'} = $stn_adaptor->fetch_tree_by_cafe_gene_family_id($self->cafe_gene_family_id());
            $_->lambdas($self->lambdas) for @{$self->{'_root'}->get_all_nodes};
        }
    }
    return $self->{'_root'};
}


=head2 root_id

    Arg[1]      : (opt.) <int> Internal ID
    Example     : my $root_id = $self->root_id
    Description : Getter/Setter for the root ID of the associated species tree
    ReturnType  : scalar
    Exceptions  : none
    Caller      : general

=cut

sub root_id {
    my ($self, $root_id) = @_;
    if (defined $root_id) {
        $self->{'_root_id'} = $root_id;
    }
    return $self->{'_root_id'};
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
    for my $node (@{$self->root->get_all_nodes}) {
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
    for my $node (@{$self->root->get_all_nodes}) {
        if (defined $node->pvalue && ($node->pvalue < $self->pvalue_lim) && $node->is_expansion) {
            push @{$expansions}, $node;
        }
    }
    return $expansions;
}


1;
