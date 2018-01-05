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

=head1 NAME

Bio::EnsEMBL::Compara::Utils::ConnectedComponents

=head1 SYNOPSIS

  my $ccEngine = new Bio::EnsEMBL::Compara::Utils::ConnectedComponents;
  $ccEngine->add_connection($node_id1, $node_id2);

  printf("%d elements split into %d distinct components\n", $ccEngine->get_element_count, $ccEngine->get_component_count);

  foreach my $link (@{$holding_node->links}) {
    my $graph = $link->get_neighbor($holding_node);
  }

=head1 DESCRIPTION

This is a general purpose tool for building connected component graphs
from pairs of scalars. The scalars can be any perl scalar (number, string,
object reference, hash reference, list reference) The scalars are treated as
distinct IDs so that equal scalars point to the same node/component.
As new scalar IDs are encountered new nodes are created and graphs are grown
and merged as the connections are added.

The holding node has a hard coded name 'ccg_holding_node' that can only be
retrieved by $ccEngine->holding_node.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Utils::ConnectedComponents;

use strict; 
use warnings;


sub new {
    my $class = shift;

    my $self = {};
    bless $self, $class;

    $self->{group_content} = {};
    $self->{group_for_node} = {};
    $self->{next_group_id} = 1;

    return $self;
}


=head2 add_connection

  Arg [1]    : <scalar> node1 identifier (some unique number, name or object/data reference)
  Arg [2]    : <scalar> node2 identifier
  Example    : $ccEngine->add_connection($id1, $id2);
               $ccEngine->add_connection($member1, $member2);
               $ccEngine->add_connection("ENG00000016598", "ENG00000076598");
  Description: Takes a pair of scalars and merge the components they belonged to (if these were different)
               Returns an identifier of the new component.
               WARNING: as components are merged, some identifiers may become invalid
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub add_connection {
    my ($self, $n1, $n2) = @_;

    my $self_group_for_node = $self->{group_for_node};
    my $self_group_content = $self->{group_content};

    my $g1 = $self_group_for_node->{$n1};
    my $g2 = $self_group_for_node->{$n2};

    # Both nodes are already in the graph
    if ($g1 and $g2) {
        # Merge the components if different
        if ($g1 != $g2) {
            # Make sure we iterate over the smallest array
            if (scalar(@{$self_group_content->{$g1}}) < scalar(@{$self_group_content->{$g2}})) {
                my $g = $g1;
                $g1 = $g2;
                $g2 = $g;
            }
            my $self_group_content_g2 = delete $self_group_content->{$g2};
            $self_group_for_node->{$_} = $g1 for @{$self_group_content_g2};
            push @{$self_group_content->{$g1}}, @{$self_group_content_g2};
        }
        return $g1;

    # Only one of the nodes is already in the graph: we add to its group
    # the other node
    } elsif ($g1) {
        push @{$self_group_content->{$g1}}, $n2;
        $self_group_for_node->{$n2} = $g1;
        return $g1;
    } elsif ($g2) {
        push @{$self_group_content->{$g2}}, $n1;
        $self_group_for_node->{$n1} = $g2;
        return $g2;

    # None of the nodes are in the graph yet, so we create a new group that
    # holds both
    } else {
        my $g = $self->{next_group_id};
        $self->{next_group_id}++;
        $self_group_content->{$g} = [$n1, $n2];
        $self_group_for_node->{$n1} = $g;
        $self_group_for_node->{$n2} = $g;
        return $g;
    }

}


=head2 get_component_count

  Example     : $ccEngine->get_component_count;
  Description : Return the number of connected components
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_component_count {
    my $self = shift;
    return scalar keys %{$self->{group_content}};
}


=head2 get_element_count

  Example     : $ccEngine->get_element_count;
  Description : Return the number of elements across all components
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_element_count {
    my $self = shift;
    return scalar(keys(%{$self->{group_for_node}}));
}


=head2 get_components

  Example     : $ccEngine->get_components();
  Description : Return the content of all components.
                NOTE: Each arrayref points to the original array stored
                in the ConnectedComponents object. Do NOT modify it.
  Returntype  : Arrayref of arrayref of elements
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub get_components {
    my $self = shift;
    return [values %{$self->{group_content}}];
}


1;
