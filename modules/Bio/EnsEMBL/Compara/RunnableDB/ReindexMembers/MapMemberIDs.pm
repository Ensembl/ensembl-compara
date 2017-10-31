=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::MapMemberIDs

This runnable dumps all members into one big FASTA file.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::MapMemberIDs;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    $self->param_required('genome_db_id');

    my $reuse_compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($self->param('prev_rel_db'));

    $self->param('current_members', $self->_fetch_members($self->compara_dba->dbc));
    $self->param('previous_members', $self->_fetch_members($reuse_compara_dba->dbc));
}

sub _fetch_members {
    my $self = shift @_;
    my $dbc = shift;

    my $sql = 'SELECT gene_member_id, gene_member.stable_id AS gene_member_stable_id, seq_member_id, seq_member.stable_id AS seq_member_stable_id, md5sum
               FROM gene_member JOIN seq_member USING (gene_member_id) JOIN sequence USING (sequence_id) WHERE gene_member.genome_db_id = ?';

    my $sth = $dbc->prepare($sql);
    $sth->execute($self->param('genome_db_id'));
    my $rows = $sth->fetchall_arrayref( {} );
    $sth->finish;
    $self->warning('Fetched ' . scalar(@$rows) . ' genes from '. $dbc->dbname);
    return {map {$_->{'gene_member_stable_id'} => $_} @$rows};
}


sub run {
    my $self = shift @_;

    my $current_members = $self->param('current_members');
    my $previous_members = $self->param('previous_members');

    my @to_rename;
    my %lost_seq;
    my %gained_seq;

    while (my ($gene_member_stable_id, $prev_data) = each %$previous_members) {
        if (my $curr_data = $current_members->{$gene_member_stable_id}) {
            # Gene in both dbs
            if ($prev_data->{'seq_member_stable_id'} eq $curr_data->{'seq_member_stable_id'}) {
                # Transcript in both dbs
                if ($prev_data->{'md5sum'} eq $curr_data->{'md5sum'}) {
                    # Same sequence
                    if (($prev_data->{'gene_member_id'} ne $curr_data->{'gene_member_id'}) or ($prev_data->{'seq_member_id'} ne $curr_data->{'seq_member_id'})) {
                        # But different dbIDs
                        push @to_rename, { 'prev' => $prev_data, 'curr' => $curr_data };
                    } else {
                        # Same dbIDs -> nothing to change
                    }
                } else {
                    # Sequence changed
                    push @{ $lost_seq{$prev_data->{'md5sum'}} }, $gene_member_stable_id;
                    push @{ $gained_seq{$curr_data->{'md5sum'}} }, $gene_member_stable_id;
                }
            } else {
                # Transcript changed
                if ($prev_data->{'md5sum'} eq $curr_data->{'md5sum'}) {
                    # Same sequence
                    push @to_rename, { 'prev' => $prev_data, 'curr' => $curr_data };
                } else {
                    # Sequence changed
                    push @{ $lost_seq{$prev_data->{'md5sum'}} }, $gene_member_stable_id;
                    push @{ $gained_seq{$curr_data->{'md5sum'}} }, $gene_member_stable_id;
                }
            }
        } else {
            # Gene gone
            push @{ $lost_seq{$prev_data->{'md5sum'}} }, $gene_member_stable_id;
        }
    }

    my @to_delete;
    # Now we compare the lost and gained sequences, and hope to find further renames
    while (my ($md5sum, $lost_gene_member_stable_ids) = each %lost_seq) {
        if (my $gained_gene_member_stable_ids = $gained_seq{$md5sum}) {
            # Sequence found in both databases
            if ((scalar(@$lost_gene_member_stable_ids) == 1) and (scalar(@$gained_gene_member_stable_ids) == 1)) {
                # Only 1 representative in each database
                my $gl = $lost_gene_member_stable_ids->[0];
                my $gg = $gained_gene_member_stable_ids->[0];
                die "Should not happen" if $gl eq $gg;
                # This is a rename
                push @to_rename, { 'prev' => $previous_members->{$gl}, 'curr' => $current_members->{$gg} };
            } else {
                # 1-to-many or many-to-many mapping -> we just delete the member
                push @to_delete, map {$previous_members->{$_}->{'seq_member_id'}} @$lost_gene_member_stable_ids;
            }
        } else {
            # Sequence completely lost
            push @to_delete, map {$previous_members->{$_}->{'seq_member_id'}} @$lost_gene_member_stable_ids;
        }
    }

    #my @new;
    #while (my ($gene_member_stable_id, $curr_data) = each %$current_members) {
    #    unless ($previous_members->{$gene_member_stable_id}) {
    #        push @new, $gene_member_stable_id;
    #    }
    #}

    $self->warning( scalar(@to_rename) . " members to rename" );
    $self->warning( scalar(@to_delete) . " members to delete" );
    $self->param('to_rename', \@to_rename);
    $self->param('to_delete', \@to_delete);
}


sub write_output {
    my $self = shift @_;
    my $to_rename = $self->param('to_rename');
    my $dbc = $self->compara_dba->dbc;
    my $offset = 1_000_000_000;     # Must be higher than the max seq_member_id
    if (scalar(@$to_rename)) {
        $self->call_within_transaction( sub {
            $dbc->do('SET FOREIGN_KEY_CHECKS=0');
            foreach my $r (@$to_rename) {
                $dbc->do('UPDATE other_member_sequence SET seq_member_id = ? WHERE seq_member_id = ?',               undef, $offset+$r->{'curr'}->{'seq_member_id'}, $r->{'prev'}->{'seq_member_id'});
                $dbc->do('UPDATE seq_member_projection SET source_seq_member_id = ? WHERE source_seq_member_id = ?', undef, $offset+$r->{'curr'}->{'seq_member_id'}, $r->{'prev'}->{'seq_member_id'});
                $dbc->do('UPDATE seq_member_projection SET target_seq_member_id = ? WHERE target_seq_member_id = ?', undef, $offset+$r->{'curr'}->{'seq_member_id'}, $r->{'prev'}->{'seq_member_id'});
                $dbc->do('UPDATE gene_tree_node SET seq_member_id = ? WHERE seq_member_id = ?',                      undef, $offset+$r->{'curr'}->{'seq_member_id'}, $r->{'prev'}->{'seq_member_id'});
                $dbc->do('UPDATE gene_align_member SET seq_member_id = ? WHERE seq_member_id = ?',                   undef, $offset+$r->{'curr'}->{'seq_member_id'}, $r->{'prev'}->{'seq_member_id'});
                $dbc->do('UPDATE homology_member SET seq_member_id = ?, gene_member_id = ? WHERE seq_member_id = ?', undef, $offset+$r->{'curr'}->{'seq_member_id'}, $r->{'curr'}->{'gene_member_id'}, $r->{'prev'}->{'seq_member_id'});
            }
            $dbc->do('SET FOREIGN_KEY_CHECKS=1');
            foreach my $r (@$to_rename) {
                $dbc->do('UPDATE other_member_sequence SET seq_member_id = ? WHERE seq_member_id = ?',               undef, $r->{'curr'}->{'seq_member_id'}, $offset+$r->{'curr'}->{'seq_member_id'});
                $dbc->do('UPDATE seq_member_projection SET source_seq_member_id = ? WHERE source_seq_member_id = ?', undef, $r->{'curr'}->{'seq_member_id'}, $offset+$r->{'curr'}->{'seq_member_id'});
                $dbc->do('UPDATE seq_member_projection SET target_seq_member_id = ? WHERE target_seq_member_id = ?', undef, $r->{'curr'}->{'seq_member_id'}, $offset+$r->{'curr'}->{'seq_member_id'});
                $dbc->do('UPDATE gene_tree_node SET seq_member_id = ? WHERE seq_member_id = ?',                      undef, $r->{'curr'}->{'seq_member_id'}, $offset+$r->{'curr'}->{'seq_member_id'});
                $dbc->do('UPDATE gene_align_member SET seq_member_id = ? WHERE seq_member_id = ?',                   undef, $r->{'curr'}->{'seq_member_id'}, $offset+$r->{'curr'}->{'seq_member_id'});
                $dbc->do('UPDATE homology_member SET seq_member_id = ? WHERE seq_member_id = ?',                     undef, $r->{'curr'}->{'seq_member_id'}, $offset+$r->{'curr'}->{'seq_member_id'});
            }
        } );
    }

    if (scalar(@$to_delete)) {
        my %root_ids_to_delete;
        my $sql = 'SELECT root_id FROM gene_tree_node JOIN gene_tree_root USING (root_id) WHERE ref_root_id IS NULL AND seq_member_id = ?';
        my $sth = $dbc->prepare($sql);
        foreach my $seq_member_id (@{$self->param('to_delete')}) {
            $sth->execute($seq_member_id);
            my ($tree_id) = $sth->fetchrow_array;
            $sth->finish;
            $root_ids_to_delete{$tree_id} = 1 if defined $tree_id;
        }
        $self->warning( scalar(keys %root_ids_to_delete) . " trees to delete" );
        my $gene_tree_adaptor = $self->compara_dba->get_GeneTreeAdaptor;
        foreach my $tree_id (keys %root_ids_to_delete) {
            $self->call_within_transaction( sub {
                my $tree = $gene_tree_adaptor->fetch_by_dbID($tree_id);
                $tree->preload;
                $gene_tree_adaptor->delete_tree($tree);
                $tree->release_tree;
            }
        }
    }
}

1;

