=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::SpeciesTreeNode

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
        delete $self->{'_taxon'};
    }
    return $self->{'_taxon_id'};
}

sub taxon {
    my ($self, $taxon) = @_;

    if (defined $taxon) {
        $self->{'_taxon_id'} = $taxon->dbID;
        $self->{'_taxon'} = $taxon;

    } elsif (defined $self->{'_taxon_id'}) {
       $self->{'_taxon'} = $self->adaptor->db->get_NCBITaxonAdaptor->fetch_node_by_taxon_id($self->{'_taxon_id'});

    } else {
        throw("taxon_id is not defined. Can't fetch Taxon without a taxon_id");
    }

    return $self->{'_taxon'};
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

sub name {
    my $self = shift;
    return $self->node_name(@_);
}

1;
