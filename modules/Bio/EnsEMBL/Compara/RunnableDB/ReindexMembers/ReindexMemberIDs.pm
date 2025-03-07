=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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
order to avoid clashes. For instance, it may be asked to change a -> b and b -> c.
In this case, it would first change b to c and then a to b.
Loops are resolved too.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::ReindexMemberIDs;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

my $offset = 1_000_000_000;     # Must be higher than the max seq_member_id

sub param_defaults {
    my $self = shift @_;
    return {
        %{ $self->SUPER::param_defaults },

        # Allows testing the code and making sure we don't break foreign keys
        'dry_run'   => 0,

        # Default values in case no pairs are present in the accu
        'seq_member_id_pairs'   => [],
        'gene_member_id_pairs'  => [],
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

    my $max_seq_member_id = $dbc->sql_helper->execute_single_result( -sql => 'SELECT MAX(seq_member_id) FROM seq_member' );
    $self->die_no_retry("max seq_member_id ($max_seq_member_id) >= reindexing offset ($offset)") if ($max_seq_member_id >= $offset);

    $self->call_within_transaction( sub {

        # Temporarily add keys to peptide_align_feature columns
        # qmember_id and hmember_id so any updates will be quick.
        $dbc->do('ALTER TABLE peptide_align_feature ADD KEY qmember_id (qmember_id)');
        $dbc->do('ALTER TABLE peptide_align_feature ADD KEY hmember_id (hmember_id)');

        foreach my $r (@{$self->param('sorted_seq_member_id_pairs')}) {
            if ($r->[0] > $offset) {
                # Insert a dummy seq_member to still honour the foreign key
                $dbc->do('INSERT INTO seq_member (seq_member_id, stable_id, source_name, taxon_id) VALUES (?,?,?,?)', undef, $r->[0], 'dummy', 'EXTERNALPEP', 1);
            } elsif ($r->[1] > $offset) {
                # And now remove it
                $dbc->do('DELETE FROM seq_member WHERE seq_member_id = ?', undef, $r->[1]);
            }
            #printf("rename seq_member_id %s to %s\n", @$r);
            $dbc->do('UPDATE seq_member_projection SET source_seq_member_id = ? WHERE source_seq_member_id = ?', undef, @$r);
            $dbc->do('UPDATE seq_member_projection SET target_seq_member_id = ? WHERE target_seq_member_id = ?', undef, @$r);
            $dbc->do('UPDATE gene_tree_node        SET seq_member_id = ?        WHERE seq_member_id = ?',        undef, @$r);
            $dbc->do('UPDATE gene_align_member     SET seq_member_id = ?        WHERE seq_member_id = ?',        undef, @$r);
            $dbc->do('UPDATE homology_member       SET seq_member_id = ?        WHERE seq_member_id = ?',        undef, @$r);
            $dbc->do('UPDATE hmm_annot             SET seq_member_id = ?        WHERE seq_member_id = ?',        undef, @$r);
            $dbc->do('UPDATE peptide_align_feature SET qmember_id = ?           WHERE qmember_id = ?',           undef, @$r);
            $dbc->do('UPDATE peptide_align_feature SET hmember_id = ?           WHERE hmember_id = ?',           undef, @$r);
        }

        $dbc->do('ALTER TABLE peptide_align_feature DROP KEY qmember_id');
        $dbc->do('ALTER TABLE peptide_align_feature DROP KEY hmember_id');

        foreach my $r (@{$self->param('sorted_gene_member_id_pairs')}) {
            if ($r->[0] > $offset) {
                # Insert a dummy gene_member to still honour the foreign key
                $dbc->do('INSERT INTO gene_member (gene_member_id, stable_id, source_name, taxon_id) VALUES (?,?,?,?)', undef, $r->[0], 'dummy', 'EXTERNALGENE', 1);
            } elsif ($r->[1] > $offset) {
                # And now remove it
                $dbc->do('DELETE FROM gene_member WHERE gene_member_id = ?', undef, $r->[1]);
            }
            #printf("rename gene_member_id %s to %s\n", @$r);
            $dbc->do('UPDATE gene_member_hom_stats SET gene_member_id = ?       WHERE gene_member_id = ?',       undef, @$r);
            $dbc->do('UPDATE homology_member       SET gene_member_id = ?       WHERE gene_member_id = ?',       undef, @$r);
        }

        die "Dry-run requested" if $self->param('dry_run');
    } );
}


## Given a list of requested changes a -> b, find the order in which to
## apply them in.
sub sort_pairs {
    my $self = shift;
    my $pairs = shift;

    $self->warning(scalar(@$pairs). " initial pairs");

    # Since only identical members can be reindexed, a given source index
    # can only be renamed once at most, and an index can only be targetted
    # once. This means that if we combine the pairs into a graph, there is
    # always at most 1 successor and at most 1 predecessor. The graph is
    # thus a collection of disconnected "lines" and "loops".
    my %successor = ();
    my %predecessor = ();
    foreach my $pair (@$pairs) {
        $successor{$pair->[0]} = $pair->[1];
        $predecessor{$pair->[1]} = $pair->[0];
    }

    my @sorted_pairs;

    # First the "lines" can be identified by their final index
    my @final_ids = grep {not exists $successor{$_}} values %successor;
    foreach my $id (@final_ids) {
        # Rewind the line and clear %successor
        while (my $prev_id = $predecessor{$id}) {
            push @sorted_pairs, [$id, $prev_id];
            $id = $prev_id;
            delete $successor{$id};
        }
    }
    $self->warning(scalar(@sorted_pairs). " pairs in lines");

    # Now only "loops" remain in the graph
    my $n_loops = 0;
    # As long as there is a loop left
    while (%successor) {
        $n_loops++;
        # Pick one node
        my $id = (keys %successor)[0];
        # Use a dummy, temporary, index
        push @sorted_pairs, [$successor{$id} + $offset, $successor{$id}];
        delete $successor{$id};
        # And rewind the loop
        while (my $prev_id = $predecessor{$id}) {
            push @sorted_pairs, [$id, $prev_id];
            $id = $prev_id;
            delete $successor{$id};
        }
        $sorted_pairs[-1]->[1] += $offset;
    }

    $self->warning("$n_loops loops");
    $self->warning(scalar(@sorted_pairs). " pairs to apply");
    if (scalar(@$pairs) != (scalar(@sorted_pairs)-$n_loops)) {
        die scalar(@$pairs), " ", scalar(@sorted_pairs), " ", $n_loops;
    }
    return \@sorted_pairs;
}

1;

