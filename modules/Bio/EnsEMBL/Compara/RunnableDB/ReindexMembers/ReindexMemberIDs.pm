=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::ReindexMemberIDs

=head1 SYNOPSIS

This runnable receives the list of index changes, and applies them in the right
order to avoid cross hits. For instance a -> b -> c is done by changing b into c
and then a into b. Loops are resolved too.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::ReindexMemberIDs;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift @_;
    return {
        %{ $self->SUPER::param_defaults },

        # Allows testing the code and making sure we don't break foreign keys
        'dry_run'   => 0,
    }
}


sub fetch_input {
    my $self = shift @_;

    $self->param('sorted_seq_member_id_pairs',   $self->sort_pairs($self->param_required('seq_member_id_pairs')));
    $self->param('sorted_gene_member_id_pairs',  $self->sort_pairs($self->param_required('gene_member_id_pairs')));
}


sub write_output {
    my $self = shift @_;

    my $dbc = $self->compara_dba->dbc;

    $self->call_within_transaction( sub {
        #$dbc->do('SET FOREIGN_KEY_CHECKS=0');
        foreach my $r (@{$self->param('sorted_seq_member_id_pairs')}) {
            #printf("rename seq_member_id %s to %s\n", @$r);
            $dbc->do('UPDATE seq_member_projection SET source_seq_member_id = ? WHERE source_seq_member_id = ?', undef, @$r);
            $dbc->do('UPDATE seq_member_projection SET target_seq_member_id = ? WHERE target_seq_member_id = ?', undef, @$r);
            $dbc->do('UPDATE gene_tree_node        SET seq_member_id = ?        WHERE seq_member_id = ?',        undef, @$r);
            $dbc->do('UPDATE gene_align_member     SET seq_member_id = ?        WHERE seq_member_id = ?',        undef, @$r);
            $dbc->do('UPDATE homology_member       SET seq_member_id = ?        WHERE seq_member_id = ?',        undef, @$r);
        }
        foreach my $r (@{$self->param('sorted_gene_member_id_pairs')}) {
            #printf("rename gene_member_id %s to %s\n", @$r);
            $dbc->do('UPDATE gene_member_hom_stats SET gene_member_id = ?       WHERE gene_member_id = ?',       undef, @$r);
            $dbc->do('UPDATE homology_member       SET gene_member_id = ?       WHERE gene_member_id = ?',       undef, @$r);
        }
        #$dbc->do('SET FOREIGN_KEY_CHECKS=1');

        die "Dry-run requested" if $self->param('dry_run');
    } );
}



sub sort_pairs {
    my $self = shift;
    my $pairs = shift;

    # If we combine the pairs into a graph, the incoming and outgoing
    # degrees of each node is either 0 or 1. This means that the graph is
    # composed of disconnected "lines" and "loops"
    my %successor = ();
    my %predecessor = ();
    foreach my $pair (@$pairs) {
        $successor{$pair->[0]} = $pair->[1];
        $predecessor{$pair->[1]} = $pair->[0];
    }

    my @sorted_pairs;

    # First the "lines"
    my @final_ids = grep {not exists $successor{$_}} values %successor;
    foreach my $id (@final_ids) {
        while (my $prev_id = $predecessor{$id}) {
            push @sorted_pairs, [$id, $prev_id];
            $id = $prev_id;
            delete $successor{$id};
        }
    }
    $self->warning(scalar(@sorted_pairs). " pairs");

    # Only loops remain in the graph
    my $offset = 1_000_000_000;     # Must be higher than the max seq_member_id
    my $n_loops = 0;
    while (%successor) {
        $n_loops++;
        my $id = (keys %successor)[0];
        push @sorted_pairs, [$successor{$id} + $offset, $successor{$id}];
        delete $successor{$id};
        while (my $prev_id = $predecessor{$id}) {
            push @sorted_pairs, [$id, $prev_id];
            $id = $prev_id;
            delete $successor{$id};
        }
        $sorted_pairs[-1]->[1] += $offset;
    }

    $self->warning("$n_loops loops");
    $self->warning(scalar(@sorted_pairs). " pairs");
    if (scalar(@$pairs) != (scalar(@sorted_pairs)-$n_loops)) {
        die scalar(@$pairs), " ", scalar(@sorted_pairs), " ", $n_loops;
    }
    return \@sorted_pairs;
}

1;

