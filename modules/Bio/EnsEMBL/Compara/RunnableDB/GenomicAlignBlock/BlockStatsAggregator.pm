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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::BlockStatsAggregator

=head1 DESCRIPTION

This Runnable aggregates (sums up) statistics that come from many jobs
(alignment blocks) and stores them as species-tree node tags.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::BlockStatsAggregator;

use strict;
use warnings;

use List::Util qw(sum);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID( $self->param_required('mlss_id') );
    $self->param('node_hash', $mlss->species_tree->get_genome_db_id_2_node_hash());

    $self->param_required($_) for qw(genome_length pairwise_coverage num_of_positions num_of_aligned_positions num_of_other_seq_positions depth_by_genome);
}

sub run {
    my $self = shift @_;

    my $pairwise_coverage = $self->param('pairwise_coverage');
    foreach my $gdb_id1 (keys %$pairwise_coverage) {
        my $node = $self->param('node_hash')->{$gdb_id1};
        foreach my $gdb_id2 (keys %{$pairwise_coverage->{$gdb_id1}}) {
            my $genome_coverage = sum( @{$pairwise_coverage->{$gdb_id1}->{$gdb_id2}} );
            $node->store_tag("genome_coverage_${gdb_id2}", $genome_coverage);
        }
    }

    foreach my $gdb_id (keys %{$self->param('num_of_positions')} ) {
        my $node                        = $self->param('node_hash')->{$gdb_id};
        my $num_of_positions            = sum(@{$self->param('num_of_positions')->{$gdb_id}});
        my $num_of_aligned_positions    = sum(@{$self->param('num_of_aligned_positions')->{$gdb_id}});
        my $num_of_other_seq_positions  = sum(@{$self->param('num_of_other_seq_positions')->{$gdb_id}});
        my $genome_length               = $self->param('genome_length')->{$gdb_id};

        $node->store_tag('genome_length',               $genome_length);
        $node->store_tag('num_of_positions_in_blocks',  $num_of_positions);
        $node->store_tag('num_of_aligned_positions',    $num_of_aligned_positions);
        $node->store_tag('num_of_other_seq_positions',  $num_of_other_seq_positions);
        $node->store_tag('average_depth',               $num_of_other_seq_positions / $genome_length);

        my $depth_breakdown = $self->param('depth_by_genome')->{$gdb_id};
        # Adjust the depth-0 counter with the positions not included in any block
        push @{$depth_breakdown->{0}}, $genome_length - $num_of_positions;
        foreach my $depth (keys %$depth_breakdown) {
            my $s = sum(@{$depth_breakdown->{$depth}});
            $node->store_tag('num_positions_depth_'.$depth, $s);
        }
    }
}

1;
