=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::GeneTree

=head1 SYNOPSIS

Tree - Class for a CAFE tree

=head1 DESCRIPTION

Specific subclass of NestedSet to add functionality when the nodes of this tree
are CAFETreeMember objects.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::CAFETreeNode
  +- Bio::EnsEMBL::Compara::NestedSet
   +- Bio::EnsEMBL::Compara::Graph::Node
    +- Bio::EnsEMBL::Compara::Graph::CGObject


=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::CAFETreeNode;

use strict;

use base ('Bio::EnsEMBL::Compara::NestedSet');

#################################################
# Object variable methods
#################################################


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

sub avg_pvalue {
    my ($self, $avg_pvalue) = @_;

    if (defined $avg_pvalue) {
        $self->{'_avg_pvalue'} = $avg_pvalue;
    }
    return $self->{'_avg_pvalue'};
}

sub fam_id {
    my ($self, $fam_id) = @_;

    if (defined $fam_id) {
        $self->{'_fam_id'} = $fam_id;
    }
    return $self->{'_fam_id'};
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

sub p_value {
    my ($self, $pvalue) = @_;

    if (defined $pvalue) {
        $self->{'_p_value'} = $pvalue;
    }
    return $self->{'_p_value'};
}

1;
