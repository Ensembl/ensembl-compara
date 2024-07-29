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

Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::MapMemberIDs

=head1 SYNOPSIS

This runnable loads the members from the current database and a previous one, compares them
and outputs a list of rename operations to do on the gene-tree tables.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::MapMemberIDs;

use strict;
use warnings;

use File::Spec::Functions qw(catfile);
use JSON qw(decode_json);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $curr_gdb_id = $self->param_required('genome_db_id');
    my $prev_gdb_id = $curr_gdb_id;

    if ($self->param('do_genome_reindexing') && $self->param('num_reindexed_genomes') > 0) {

        my $reindexing_dir = $self->param_required('genome_reindexing_dir');
        my $gdb_map_file = catfile($reindexing_dir, 'genome_db_id.json');
        my $gdb_reindexing_map = decode_json($self->_slurp($gdb_map_file));
        my %gdb_reindexing_rev_map = reverse %{$gdb_reindexing_map};

        if (exists $gdb_reindexing_rev_map{$curr_gdb_id}) {
            $prev_gdb_id = $gdb_reindexing_rev_map{$curr_gdb_id};
        }
    }

    my $reuse_compara_dba = $self->get_cached_compara_dba('prev_tree_db');

    $self->param('current_members', $self->_fetch_members($self->compara_dba->dbc, $curr_gdb_id));
    $self->param('previous_members', $self->_fetch_members($reuse_compara_dba->dbc, $prev_gdb_id));
}

sub _fetch_members {
    my ($self, $dbc, $genome_db_id) = @_;

    my $sql = 'SELECT gene_member_id, gene_member.stable_id AS gene_member_stable_id, seq_member_id, seq_member.stable_id AS seq_member_stable_id, md5sum
               FROM gene_member JOIN seq_member USING (gene_member_id) JOIN sequence USING (sequence_id) WHERE gene_member.genome_db_id = ?';

    my $sth = $dbc->prepare($sql);
    $sth->execute($genome_db_id);
    my $rows = $sth->fetchall_arrayref( {} );   # Get an arrayref of hashrefs
    $sth->finish;
    $self->warning('Fetched ' . scalar(@$rows) . ' genes from '. $dbc->dbname);
    return {map {$_->{'gene_member_stable_id'} => $_} @$rows};  # Returns the rows hashed by gene_member_stable_id
}


sub run {
    my $self = shift @_;

    my $current_members = $self->param('current_members');
    my $previous_members = $self->param('previous_members');

    # NOTE: make sure you cover all the cases ! The best way is to make
    #       sure each "if" has an "else", and comment out all the branches

    # To accumulate the result of the comparison
    my @to_rename;
    my @to_delete;
    $self->param('to_rename', \@to_rename);
    $self->param('to_delete', \@to_delete);

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
                push @to_delete, map {$previous_members->{$_}} @$lost_gene_member_stable_ids;
            }
        } else {
            # Sequence completely lost
            push @to_delete, map {$previous_members->{$_}} @$lost_gene_member_stable_ids;
        }
    }

    # "New" members are not needed, but they could be listed this way
    #my @new;
    #while (my ($gene_member_stable_id, $curr_data) = each %$current_members) {
    #    unless ($previous_members->{$gene_member_stable_id}) {
    #        push @new, $gene_member_stable_id;
    #    }
    #}

    $self->warning( scalar(@to_rename) . " members to rename" );
    $self->warning( scalar(@to_delete) . " members to delete" );
}


sub write_output {
    my $self = shift @_;

    my $to_delete = $self->param('to_delete');
    foreach my $m (@$to_delete) {
        $self->dataflow_output_id($m, 2);
    }

    my $to_rename = $self->param('to_rename');
    foreach my $r (@$to_rename) {
        $self->dataflow_output_id( {
                'seq_member_ids'    => [$r->{'prev'}->{'seq_member_id'},  $r->{'curr'}->{'seq_member_id'}],
                'gene_member_ids'   => [$r->{'prev'}->{'gene_member_id'}, $r->{'curr'}->{'gene_member_id'}],
            }, 3 );
    }
}

1;

