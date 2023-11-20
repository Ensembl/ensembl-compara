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

Bio::EnsEMBL::Compara::RunnableDB::HAL::AggregateHalGenomicCoverage

=head1 DESCRIPTION

Aggregate genomic coverage for a GenomeDB represented in a HAL file.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::AggregateHalGenomicCoverage;

use strict;
use warnings;

use List::Util qw(sum);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'hal_sequence_names' => [],
        'num_aligned_positions_by_chunk' => {},
        'num_positions_by_chunk' => {},
    };
}


sub run {
    my $self = shift @_;

    my %hal_sequence_names = map { $_ => 1 } @{$self->param_required('hal_sequence_names')};
    my $accu_num_aligned_positions = $self->param_required('num_aligned_positions_by_chunk');
    my $accu_num_positions = $self->param_required('num_positions_by_chunk');

    my $genome_db_id = $self->param_required('genome_db_id');

    my $genome_db_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
    my $genome_db = $genome_db_adaptor->fetch_by_dbID($genome_db_id);

    my $dnafrag_adaptor = $self->compara_dba->get_DnaFragAdaptor;
    my $dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB($genome_db);

    my $num_aligned_positions_in_genome = 0;
    my $num_positions_in_genome = 0;
    foreach my $dnafrag (@{$dnafrags}) {

        my $dnafrag_name = $dnafrag->name;
        my $dnafrag_length = $dnafrag->length;

        # A dnafrag that is not in the HAL file cannot have alignment coverage,
        # but we still include its length in the total length of the genome.
        if (!exists $hal_sequence_names{$dnafrag_name}) {
            # Exclude if it is not a reference:
            if (!$dnafrag->is_reference()){
                next;
            }
            $num_positions_in_genome += $dnafrag_length;
            next;
        }

        my %chunk_data;
        while (my ($chunk_offset, $num_aligned_positions) = each %{$accu_num_aligned_positions->{$dnafrag_name}}) {
            $chunk_data{$chunk_offset}{'num_aligned_positions'} = $num_aligned_positions;
        }

        while (my ($chunk_offset, $num_positions) = each %{$accu_num_positions->{$dnafrag_name}}) {
            $chunk_data{$chunk_offset}{'num_positions'} = $num_positions;
        }

        my @offsets = sort { $a <=> $b } keys %chunk_data;

        my $initial_offset = $offsets[0];
        if ($initial_offset != 0) {
            $self->die_no_retry("initial '$dnafrag_name' chunk offset must be zero, not $initial_offset");
        }

        my $final_position = $offsets[-1] + $chunk_data{$offsets[-1]}{'num_positions'};
        if ($final_position != $dnafrag_length) {
            $self->die_no_retry("final dnafrag chunk end ($final_position) does not match length of '$dnafrag_name' ($dnafrag_length)");
        }

        for (my $i = 0 ; $i < scalar(@offsets) - 1; $i++) {
            my $curr_offset = $offsets[$i];
            my $next_offset = $offsets[$i + 1];
            my $curr_chunk_length = $chunk_data{$curr_offset}{'num_positions'};
            if ($curr_offset + $curr_chunk_length != $next_offset) {
                $self->die_no_retry("mismatch between consecutive dnafrag chunks at offsets $curr_offset and $next_offset of '$dnafrag_name'");
            }
        }

        $num_aligned_positions_in_genome += sum map { $_->{'num_aligned_positions'} } values %chunk_data;
        $num_positions_in_genome += sum map { $_->{'num_positions'} } values %chunk_data;
    }

    $self->param('num_aligned_positions', $num_aligned_positions_in_genome);
    $self->param('num_positions', $num_positions_in_genome);
}


sub write_output {
    my $self = shift;

    my $genome_db_id = $self->param('genome_db_id');
    my $num_aligned_positions = $self->param('num_aligned_positions');
    my $num_positions = $self->param('num_positions');

    my $mlss_id = $self->param_required('mlss_id');
    my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    $mlss->store_tag("genome_coverage_${genome_db_id}", $num_aligned_positions);
    $mlss->store_tag("genome_length_${genome_db_id}", $num_positions);
}


1;
