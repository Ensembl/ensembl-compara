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

Bio::EnsEMBL::Compara::SpeciesTreeNode

=head1 SYNOPSIS


=head1 DESCRIPTION

Specific subclass of the NestedSet to handle species trees

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::SpeciesTreeNode
  +- Bio::EnsEMBL::Compara::NestedSet

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with an underscore (_).

=cut

package Bio::EnsEMBL::Compara::SpeciesTreeNode;

use strict;
use base ('Bio::EnsEMBL::Compara::NestedSet');

=head2 new_from_NCBITaxon

    Arg[1]      : NCBITaxon object
    Example     : my $st_node = Bio::EnsEMBL::Compara::SpeciesTreeNode->new_from_NCBITaxon($ncbi_taxon);
    Description : Constructor for species tree nodes. Given a NCBITaxon (possibly a tree), creates a new SpeciesTreeNode (possibly a tree).
    ReturnType  : EnsEMBL::Compara::SpeciesTreeNode
    Exceptions  : none
    Caller      : General

=cut

sub new_from_NCBITaxon {
    my ($self, $taxon_tree) = @_;

    my $tree = $taxon_tree->cast('Bio::EnsEMBL::Compara::SpeciesTreeNode');

    my $genomeDB_Adaptor = $taxon_tree->adaptor->db->get_GenomeDBAdaptor;
    my $NCBITaxon_Adaptor = $taxon_tree->adaptor->db->get_NCBITaxonAdaptor;
    for my $node (@{$tree->get_all_nodes}) {
        if ($node->is_leaf) {
            my $name = $self->_normalize_species_name($node->name);
            my $genomeDB = $genomeDB_Adaptor->fetch_by_name_assembly($name);
            $node->genome_db_id($genomeDB->dbID);
            $node->taxon_id($genomeDB->taxon_id); ## taxon_id shouldn't be in the taxon node already?
        } else {
            my $name = $node->name;
            $node->taxon_id($NCBITaxon_Adaptor->fetch_node_by_name($name)->taxon_id);
        }
    }
    return $tree;
}

sub _normalize_species_name {
    my ($self, $name) = @_;
    $name =~ s/\./_/g;  ## TODO: Very specific to CAFE TREES? Fix?.
    $name =~ s/ /_/g;
    $name = lc($name);
    return $name;
}

sub find_node_by_field_value {
    my ($self, $field, $expected) = @_;

    return undef unless ($self->can($field));
    my $value = $self->$field();
    print STDERR "VALUE FOR $field IS $value\n";
    return $self if ($value eq $expected);

    for my $child (@{$self->children}) {
        my $found = $child->find_node_by_field_value($field, $expected);
        return $found if (defined ($found))
    }
    return undef;
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

sub genome_db_id {
    my ($self, $genome_db_id) = @_;
    if (defined $genome_db_id) {
        $self->{'_genome_db_id'} = $genome_db_id;
    }
    return $self->{'_genome_db_id'};
}

sub node_name {
    my ($self, $name) = @_;
    if (defined $name) {
        $self->{'_node_name'} = $name;
    }
    return $self->{_node_name};
}

1;
