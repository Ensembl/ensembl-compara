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
use warnings;

use base ('Bio::EnsEMBL::Compara::NestedSet');


sub _complete_cast_node {
    my ($self, $orig) = @_;
    $self->taxon_id($orig->taxon_id);
    $self->node_name($orig->name);
}


sub find_nodes_by_field_value {
    my ($self, $field, $expected) = @_;

    return unless $self->can($field);
    my @nodes;
    for my $node (@{$self->get_all_nodes}) {
        push @nodes, $node if ($node->$field eq $expected);
    }
    return [@nodes];
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

sub genome_db {
    my ($self) = @_;
    return undef unless ($self->is_leaf);
    my $genome_db_id = $self->genome_db_id;
    return undef unless (defined $genome_db_id);
    my $genomeDBAdaptor = $self->adaptor->db->get_GenomeDBAdaptor;
    return $genomeDBAdaptor->fetch_by_dbID($self->genome_db_id);
}

sub node_name {
    my ($self, $name) = @_;
    if (defined $name) {
        $self->{'_node_name'} = $name;
    }
    return $self->{_node_name};
}

1;
