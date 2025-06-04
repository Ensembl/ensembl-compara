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

Bio::EnsEMBL::Compara::RunnableDB::HAL::halSeqChunkFactory

=head1 DESCRIPTION

Info about HAL genome sequence chunks is dataflowed on branch 2,
while the HAL sequence name is dataflowed on branch 3.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::halSeqChunkFactory;

use strict;
use warnings;

use List::Util qw(min);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'chunk_size' => 1_000_000,
    }
}

sub run {
    my $self = shift @_;

    my $hal_genome_name = $self->param_required('hal_genome_name');
    my $hal_stats_exe = $self->param_required('hal_stats_exe');

    my $hal_file_path;
    if ($self->param_is_defined('hal_file')) {
        $hal_file_path = $self->param('hal_file');
    } else {
        my $mlss_id = $self->param_required('mlss_id');
        my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
        $hal_file_path = $mlss->url;
    }

    my $cmd = [
        $hal_stats_exe,
        '--chromSizes',
        $hal_genome_name,
        $hal_file_path,
    ];

    my @chrom_size_lines = $self->get_command_output($cmd, { die_on_failure => 1 });
    my @chrom_size_pairs = map { [ split /\t/ ] } @chrom_size_lines;

    @chrom_size_pairs = sort {
        ($a->[0]=~/^[0-9]+$/ && $b->[0]=~/^[0-9]+$/) ? $a->[0] <=> $b->[0] : $a->[0] cmp $b->[0]
    } @chrom_size_pairs;

    my %hal_seq_index_map;
    my %hal_seq_length_map;
    while (my ($hal_sequence_index, $chrom_size_pair) = each (@chrom_size_pairs)) {
        my ($hal_sequence_name, $hal_sequence_length) = @$chrom_size_pair;
        $hal_seq_length_map{$hal_sequence_name} = $hal_sequence_length;
        $hal_seq_index_map{$hal_sequence_name} = $hal_sequence_index;
    }

    my @hal_regions;
    if (@chrom_size_pairs) {
        foreach my $chrom_size_pair (@chrom_size_pairs) {
            my ($hal_sequence_name, $hal_sequence_length) = @$chrom_size_pair;
            push(@hal_regions, {
                'hal_sequence_index' => $hal_seq_index_map{$hal_sequence_name},
                'hal_sequence_name' => $hal_sequence_name,
                'hal_region_start' => 0,
                'hal_region_end' => $hal_sequence_length,
            });
        }
    }

    $self->param('hal_regions', \@hal_regions);
}

sub write_output {
    my $self = shift;

    my $hal_chunk_index = 0;
    my $req_chunk_length = $self->param_required('chunk_size');
    foreach my $rec (@{$self->param('hal_regions')}) {

        $self->dataflow_output_id({ 'hal_sequence_name' => $rec->{'hal_sequence_name'} }, 3);

        for (my $offset = $rec->{'hal_region_start'}; $offset < $rec->{'hal_region_end'}; $offset += $req_chunk_length) {
            my $chunk_length = min($req_chunk_length, $rec->{'hal_region_end'} - $offset);
            my $h = {
                'hal_chunk_index'   => $hal_chunk_index,
                'hal_sequence_index' => $rec->{'hal_sequence_index'},
                'hal_sequence_name' => $rec->{'hal_sequence_name'},
                'chunk_offset'      => $offset,
                'chunk_length'      => $chunk_length,
            };
            $self->dataflow_output_id($h, 2);
            $hal_chunk_index += 1;
        }
    }
}


1;
