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

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BlastFactory

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BlastFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Data::Dumper;

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'step'               => 250,
        'all_blast_params'   => [],   # a list of arrayrefs with the size ranges
    };
}

# fetch_input is expected to populate an array in $self->param('query_members')

sub write_output {
    my $self = shift @_;

    my $step = $self->param_required('step');
    my $chunk_by_size = scalar(@{$self->param_required('all_blast_params')});

    if ( $chunk_by_size ){
        # sort members by decending sequence length
        my @sorted_members = sort { $a->seq_length <=> $b->seq_length } @{ $self->param('query_members') };
        $self->param('query_members', \@sorted_members);
    }
    my @member_id_list = (map {$_->dbID} @{$self->param('query_members')});

    my $member_length = {map {$_->dbID => $_->seq_length} @{$self->param('query_members')}};
    $self->param('seq_length', $member_length);

    while (@member_id_list) {
        my @job_array = splice(@member_id_list, 0, $step);
        
        my ( $param_index, $new_job_array, $leftover_members );
        if ( $chunk_by_size ){
            # sort job_array by seq_length from high to low
            ( $param_index, $new_job_array, $leftover_members ) = $self->_check_job_array_lengths( \@job_array );
            @job_array = @{ $new_job_array };
            unshift @member_id_list, @{ $leftover_members };
        }
        
        # print "SELECT sm.seq_member_id, s.length FROM seq_member AS sm JOIN sequence AS s USING (sequence_id) WHERE sm.seq_member_id IN (" . join( ',', @job_array ) . ")\n";

            my $output_id = {};
            if ( $chunk_by_size ) {
                $output_id->{ 'param_index'   }  = $param_index;
                $output_id->{ 'member_id_list' } = \@job_array;  
            }
            else {
                $output_id->{'start_member_id'} = $job_array[0];
                $output_id->{'end_member_id'  } = $job_array[-1];
            }

            # print "flowing...";
            # print Dumper $output_id;

            $self->flow_blast_jobs($output_id);
    }
}

=head2 _check_job_array_lengths

  Description: split given array into two arrays - 
    1. seq_member_ids that match the range (decided by the length of the first element)
    2. seq_member_ids whose length is too big for the range
  and report blast parameter granularity level

  Returns:
  1. "blast_level" for adjusting the blast parameters to suit the query length
  2. in-range member ids
  3. out-of-range "leftover" member ids

=cut

sub _check_job_array_lengths {
    my ( $self, $job_array ) = @_;
    my @job_array = @{ $job_array };

    # find level based on first element
    my @level_ranges = @{ $self->param_required('all_blast_params') };
    my $base_length  = $self->_get_length_by_member_id( $job_array[0] );
    # print "BASE LEN: $base_length\t";
    my ( $level, @range );
    foreach my $k (0..(scalar(@level_ranges)-1)) {
        @range = @{ $level_ranges[$k] };
        if ( $base_length >= $range[0] && $base_length < $range[1] ){
            $level = $k;
            # print "!!! LEVEL $k !!!\n";
            last;
        }
    }

    # find point at which seqs become too long for range
    my $j;
    my $ja_len = scalar( @{$job_array} )-1;
    foreach my $i ( 0..$ja_len ){
        if ( $self->_get_length_by_member_id( $job_array[$i] ) >= $range[1] ){
            $j = $i;
            last;
        }
    }
    $j ||= scalar( @{$job_array} );

    # split out in-range and out-of-range seq_member ids
    my @new_job_array = splice(@job_array, 0, $j);

    return ( $level, \@new_job_array, \@job_array );
}

sub _get_length_by_member_id {
    my ( $self, $member_id ) = @_;

    return $self->param('seq_length')->{$member_id};
}

1;
