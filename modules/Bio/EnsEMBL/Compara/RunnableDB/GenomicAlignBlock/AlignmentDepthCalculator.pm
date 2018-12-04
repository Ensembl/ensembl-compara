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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Alignment_depth_calculator

=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::AlignmentDepthCalculator;

use strict;
use warnings;
use Data::Dumper;
use Storable 'dclone';
use Exporter;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
#    	'genomic_align_block_id'           => '11320000002048',
#    	'compara_db' 					   => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_93',
#    	'fan_branch_code'   => 2,
    }
}

sub fetch_input {
    my $self         = shift @_;
    my $gab_adaptor = $self->compara_dba->get_GenomicAlignBlockAdaptor;
    $self->param('genomic_align_block', $gab_adaptor->fetch_by_dbID($self->param('genomic_align_block_id')));
    my $GAB = $self->param_required('genomic_align_block');

    $self->param('genomic_aligns', $GAB->genomic_align_array());
  
    print "$_->dbID \n" foreach $self->param('genomic_aligns');
}

sub run {
    my $self = shift @_;
    if(!@{$self->param('genomic_aligns')}) {
        print "\n ----- all the genomic aligns are ancestral so we bow out here \n" if ( $self->debug >3 );
        return;
    }
    $self->disconnect_from_databases;
    $self->_get_alignment_depth();
}

#this sub parses a cigar line like this -> 4m6d into this -> [['4','M'],['6','D']]
sub _decompose_cigar {
    my ($self, $member) = @_;
    print "\n we are now in _decompose_cigar, incoming member : ", $member->dbID, "\n\n\n" if ( $self->debug >3 );
    my $cigar_array = $member->get_cigar_arrayref;
#    print "\n this is the cigar_array  : \n";
#    print Dumper($cigar_array);
    my @decomposed_cigar_array;
    foreach my $cig (@{$cigar_array}) {
        my ( $numbers, $letters );
        if (length($cig) == 1) {
            ( $numbers, $letters ) = (1,$cig)
        } 
        else { 
            $cig =~ ( /^(\d+)([a-zA-Z]+)$/);
            ( $numbers, $letters ) = ( $1,$2);
        }
        my $temp = [$letters,$numbers];
        push(@decomposed_cigar_array, $temp);
    }
    return \@decomposed_cigar_array;
}

sub _get_alignment_depth {
    my $self = shift;
    print "\n we are now in _get_alignment_depth \n\n\n " if ( $self->debug >3 );
    my @cigar_lines_arrays;
    my $member_counter = 0;
    my @member_identifier;

    foreach my $member ( @{ $self->param('genomic_aligns') } ) {
    	$member_identifier[$member_counter] = $member;
        #get cigar line and separate the letters from the numbers
        my $processed_array = $self->_decompose_cigar($member);
        $cigar_lines_arrays[$member_counter] =$processed_array;
        $member_counter++;
    }
#    print Dumper(\@cigar_lines_arrays), "\n ^^^^ that was the cigar_lines_arrays \n ";
#    print "\n this is member counter : ", $member_counter;
    #cigar_lines_arrays => [
    #           member_1    [[D,3], [M,3], [D2]],
    #           member_2    [[M,8]],
    #           member_3    [[D,1], [M,5], [D,2]]
    #                      ]

    # We could use this example to test the code:
    # We need to comment the declarations of cigar_lines_arrays and member_counter above and redefine them like this:
    #my @v1 = ('D',3);
    #my @v2 = ('M',3);
    #my @v3 = ('D',2);
    #my @v4 = ('M',8);
    #my @v5 = ('D',1);
    #my @v6 = ('M',5);
    #my @v7 = ('D',2);

    #my @m1 = (\@v1,\@v2,\@v3);
    #my @m2 = (\@v4);
    #my @m3 = (\@v5,\@v6,\@v7);

    #$cigar_lines_arrays[0] = \@m1;
    #$cigar_lines_arrays[1] = \@m2;
    #$cigar_lines_arrays[2] = \@m3;
    #$member_counter = 3;

    #print Dumper @cigar_lines_arrays;
    #print scalar(@cigar_lines_arrays)."\n";
    #print "$cigar_lines_arrays[0]->[0]->[0]\n";

    #load

    #Contains the sum of the aligned sequences per alignment column (iteration)
#    my $cigar_lines_arrays = [ [ ['D',3],['M',3],['D',2] ], [ ['M',8] ], [['D',1],['M',5],['D',2]] ];
#    $member_counter= 3;
    my %alignment_depth_hash;
    
    for ( my $member = 0; $member < $member_counter; $member++ ) {
        my $position_counter = 0; #the position we are currently checking in the alignment
        my @working_copy_cigar_lines_arrays = @{ dclone(\@cigar_lines_arrays)};
        my $current_member_gid = $member_identifier[$member]->genome_db()->dbID; #gid stands for genome id

        while (scalar(@{ $working_copy_cigar_lines_arrays[0] })) {
            my $query_match = 0;
            if ( $working_copy_cigar_lines_arrays[$member]->[0]->[0] eq 'M' ) {
#                print "\n we found a matchhhhhhh \n";
                $alignment_depth_hash{$current_member_gid}{$position_counter}= [];
                $query_match = 1;
            } 

            for ( my $member1 = 0; $member1 < $member_counter; $member1++ ) {
                #We always read the first element, No need to iterate in the position we always read from position 0
                my $temp_member_gid = $member_identifier[$member1]->genome_db()->dbID;
                if ($temp_member_gid != $current_member_gid && $query_match) { #deals with duplication and also matching against the same member as the query member.
#                    print "\n passs 11111111";
                    if (! grep(/^$temp_member_gid/, @{$alignment_depth_hash{$current_member_gid}{$position_counter}} ) ){ #ensures we don't match the same genome twice, in case the other genomes are duplicated .
#                        print "\n passss 2222222\n";
                        if ( $working_copy_cigar_lines_arrays[$member1]->[0]->[0] eq 'M' ) {
#                            print "\n we are innnnnnnn \n";
                            push(@{$alignment_depth_hash{$current_member_gid}{$position_counter}}, $temp_member_gid);
                        }
                    }
                }
                #now we remove the postion we just checked from the array
                $working_copy_cigar_lines_arrays[$member1]->[0]->[1]--;
                if ( $working_copy_cigar_lines_arrays[$member1]->[0]->[1] == 0 ) {
                    shift(@{ $working_copy_cigar_lines_arrays[$member1] });
                }
            }
#            print Dumper(\%alignment_depth_hash);
#            print "\n that was alignment_depth_ and positions ^^^^ \n";
            $position_counter++;
        }## end while ( scalar(@working_copy_cigar_lines_arrays...))

    } 
    
    foreach my $genome_id ( keys %alignment_depth_hash ) {
        my @pos_array = keys %{$alignment_depth_hash{$genome_id}};
        my $sum_aligned_bases =0;
        foreach my $pos (@pos_array) {
            $sum_aligned_bases += scalar @{$alignment_depth_hash{$genome_id}->{$pos}};
        }
        print " \n genome_id : $genome_id,   number of positions : ", scalar @pos_array, "   number of aligned bases : $sum_aligned_bases \n\n\n" if ( $self->debug >3 );
        $self->dataflow_output_id({ 'genome_db_id' => $genome_id, 'num_of_aligned_positions' => scalar @pos_array} ,2); 
        $self->dataflow_output_id({ 'genome_db_id' => $genome_id, 'sum_aligned_seq' => $sum_aligned_bases} ,3);
    }
}


1;