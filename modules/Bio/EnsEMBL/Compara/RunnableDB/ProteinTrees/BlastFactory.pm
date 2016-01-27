=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastFactory 

=head1 DESCRIPTION

Fetch sorted list of member_ids and create jobs for BlastAndParsePAF. 
Supported keys:

   'genome_db_id' => <number>
       Genome_db id. Obligatory

   'step' => <number>
       How many sequences to write into the blast query file. Default 100

   'species_set_id' => <number> (optionnal)
       The species set on which we want to run blast for that genome_db_id
       Default: uses all the GenomeDBs

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Data::Dumper;

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'step'               => 10,
        'species_set_id'     => undef,
        'blast_level_ranges' => { # define sequence lengths that define different granularity of parameters
            1 => [ 0,   35  ],
            2 => [ 35,  50  ],
            3 => [ 50,  100 ],
            4 => [ 100, 10000000 ], # should really be infinity, but ten million should be big enough
        },
        'blast_params_by_length' => { # params, evalues to use for each level of length granularity
            1 => [ "-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix PAM30 -word_size 2",    2e-7 ],
            2 => [ "-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix PAM70 -word_size 2",    1e-7 ],
            3 => [ "-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix BLOSUM80 -word_size 2", 1e-8  ],
            4 => [ "-seg no -max_hsps 1 -use_sw_tback -num_threads 1 -matrix BLOSUM62 -word_size 3", 1e-10 ],
        },
        chunk_by_size => 1
        
    };
}


sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param_required('genome_db_id');

    my $species_set_id = $self->param('species_set_id');
    my $target_genome_dbs = $species_set_id ? $self->compara_dba->get_SpeciesSetAdaptor->fetch_by_dbID($species_set_id)->genome_dbs : $self->compara_dba->get_GenomeDBAdaptor->fetch_all;
    # Polyploids have no genes, and hence no blastp database
    $self->param('target_genome_dbs', [grep {not $_->is_polyploid} @$target_genome_dbs]);

    my $all_canonical = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_canonical_by_GenomeDB($genome_db_id);

    print "GDB ID: $genome_db_id\n";
    print "all_canonical: ";
    print scalar @{ $all_canonical };
    print "\n";

    if ( $self->param('chunk_by_size') ){
        # sort members by decending sequence length
        my @sorted_members = sort { $a->seq_length <=> $b->seq_length } @{ $all_canonical };
        $all_canonical = \@sorted_members;
    }
    $self->param('query_members', $all_canonical);
}


sub write_output {
    my $self = shift @_;

    my $step = $self->param('step');

    my @member_id_list = (map {$_->dbID} @{$self->param('query_members')});
    #my @member_id_list = sort {$a <=> $b} (map {$_->dbID} @{$self->param('query_members')});
    my @target_genome_db_ids = sort {$a <=> $b} (map {$_->dbID} @{$self->param('target_genome_dbs')});

    my $member_length = {map {$_->dbID => $_->seq_length} @{$self->param('query_members')}};
    $self->param('seq_length', $member_length);

    #my $c = 0;
    while (@member_id_list) {
        my @job_array = splice(@member_id_list, 0, $step);
        
        my ( $param_index, $new_job_array, $leftover_members );
        if ( $self->param('chunk_by_size') ){
            # sort job_array by seq_length from high to low
            #( $blast_params, $evalue, $new_job_array, $leftover_members ) = $self->_check_job_array_lengths( \@job_array );
            ( $param_index, $new_job_array, $leftover_members ) = $self->_check_job_array_lengths( \@job_array );
            @job_array = @{ $new_job_array };
            unshift @member_id_list, @{ $leftover_members };
        }
        
        # print "SELECT sm.seq_member_id, s.length FROM seq_member AS sm JOIN sequence AS s USING (sequence_id) WHERE sm.seq_member_id IN (" . join( ',', @job_array ) . ")\n";

        foreach my $target_genome_db_id (@target_genome_db_ids) {
            my $output_id = {'genome_db_id' => $self->param('genome_db_id'), 'target_genome_db_id' => $target_genome_db_id};
            if ( $self->param('chunk_by_size') ) {
                $output_id->{ 'param_index'   }  = $param_index;
                $output_id->{ 'member_id_list' } = \@job_array;  
            }
            else {
                $output_id->{'start_member_id'} = $job_array[0];
                $output_id->{'end_member_id'  } = $job_array[-1];
            }

            # print "flowing...";
            # print Dumper $output_id;

            $self->dataflow_output_id($output_id, 2);
        }
        #$c++;
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
    my %level_ranges = %{ $self->param_required('blast_level_ranges') };
    my $base_length  = $self->_get_length_by_member_id( $job_array[0] );
    # print "BASE LEN: $base_length\t";
    my ( $level, @range );
    foreach my $k ( keys %level_ranges ) {
        @range = @{ $level_ranges{$k} };
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

    # fetch appropriate blast params for seq len
    # my %blast_params_by_length = %{ $self->param('blast_params_by_length') };
    # my ( $blast_params, $evalue ) = @{ $blast_params_by_length{$level} };

    return ( $level, \@new_job_array, \@job_array );
}

sub _get_length_by_member_id {
    my ( $self, $member_id ) = @_;

    return $self->param('seq_length')->{$member_id};
}

1;
