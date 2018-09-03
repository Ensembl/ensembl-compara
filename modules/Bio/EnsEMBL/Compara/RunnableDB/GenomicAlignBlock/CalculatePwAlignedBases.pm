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

Bio::EnsEMBL::Compara::RunnableDB::Calculate_pw_aligned_bases

=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::CalculatePwAlignedBases;

use strict;
use warnings;
use Storable 'dclone';
use Data::Dumper;
use base 'Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::AlignmentDepthCalculator';


sub param_defaults {
    return {
#    	'genomic_align_block_id'           => '11320000002048',
#    	'compara_db' 					   => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_92',
#    	'fan_branch_code'   => 2,
    }
}

sub fetch_input {
    my $self = shift @_;
    my $gab_adaptor = $self->compara_dba->get_GenomicAlignBlockAdaptor;
    $self->param('genomic_align_block', $gab_adaptor->fetch_by_dbID($self->param_required('genomic_align_block_id')));
    my $GAB = $self->param_required('genomic_align_block');
    $self->param('genomic_aligns', $GAB->genomic_align_array()) or die "Could not fetch genomic_aligns object with genomic_align_block object='$GAB->dbID'";
    my %genomic_aligns_hash;

    #create an hash where the key is the genome db id of the genomic align object and the value is an array of all the genomic aligns belonging to that genome
    foreach my $ga (@{$self->param('genomic_aligns')}) {
        unless (exists ($genomic_aligns_hash{$ga->genome_db->dbID})) {
            $genomic_aligns_hash{$ga->genome_db->dbID} = [];
        }
        push @{$genomic_aligns_hash{$ga->genome_db->dbID}}, $ga;
    }

    $self->param('genomic_aligns_hash', \%genomic_aligns_hash);
#    print $_->dbID," \n" foreach (@{$self->param('genomic_aligns')}) if ( $self->debug >3 );
}


sub run {
    my $self = shift @_;
    my @gdbs = keys %{$self->param('genomic_aligns_hash')};
    print "\n we are now in RUN of AlignmentDepthCalculator \n" ;
    for (my $pos = 0; $pos<scalar @gdbs; $pos++) {
        for (my $inner_pos = $pos+1; $inner_pos < scalar @gdbs; $inner_pos++){
            if (scalar @{$self->param('genomic_aligns_hash')->{$gdbs[$inner_pos]}} > 1) {
                $self->_calculate_duplicate_coverage($gdbs[$pos], $gdbs[$inner_pos]);
            }
            else{
                $self->_calculate_standard_coverage($gdbs[$pos], $gdbs[$inner_pos]);
            }
            #do the reverse
            if (scalar @{$self->param('genomic_aligns_hash')->{$gdbs[$pos]}} > 1) {
                $self->_calculate_duplicate_coverage($gdbs[$inner_pos], $gdbs[$pos]);
            }
            else{
                $self->_calculate_standard_coverage($gdbs[$inner_pos], $gdbs[$pos]);
            }
        }
    }
}



sub _calculate_standard_coverage {
    my $self = shift;
    my ($gid1, $gid2) = @_;
    print "\n we are now in _calculate_standard_coverage  $gid1 VS $gid2  \n" if ( $self->debug >3 );
    my $include_original_region = 1; # we want map_coordinates to return the original regions as well as the mapped regions in the result since we don't need this. 
    foreach my $ga1 (@{$self->param('genomic_aligns_hash')->{$gid1}}) { #usind foreach loop because there can be more than one genomic align 
        my @mapped_coords;
        my $ga1_mapper = $ga1->get_Mapper();
        my $ga2 = $self->param('genomic_aligns_hash')->{$gid2}->[0]; #not using a loop here because there should only be one genomic align
        my $ga2_mapper = $ga2->get_Mapper;
        print " \n ref start ", $ga1->dnafrag_start, " ref end " , $ga1->dnafrag_end,  "  = ", ($ga1->dnafrag_end-$ga1->dnafrag_start), " \n" if ( $self->debug >3 );
        my @ga1_coords_map_with_aln_coords = $ga1_mapper->map_coordinates('SEQUENCE', $ga1->dnafrag_start, $ga1->dnafrag_end, $ga1->dnafrag_strand,'sequence', $include_original_region); # returns an array of seq coordinates mapped to aln coordinates in mapper pair objects for the source species
        
        foreach my $ga1_Seq_aln_mapped_pair (@ga1_coords_map_with_aln_coords) {
            if (ref($ga1_Seq_aln_mapped_pair->{original}) eq 'Bio::EnsEMBL::Mapper::Gap' ) { #gaps do not have coordinates in the seqs. so we romove then
                next;
            }
            my $ga1_aln_coord = $ga1_Seq_aln_mapped_pair->{mapped}; #get the alnment coords for the mapped source sequence
            my $strand = $ga1_aln_coord->{strand};
            my @ga2_coords_map_with_ga1_aln_coords = $ga2_mapper->map_coordinates('ALIGNMENT',$ga1_aln_coord->{start}, $ga1_aln_coord->{end}, $strand,'alignment',$include_original_region); #map the alignment coordinates from the source species genomic_aligns mapper object to the sequence coordinate of the target species genomic_aligns mapper object
            foreach my $ga2_linked_coord (@ga2_coords_map_with_ga1_aln_coords) {
                if (ref($ga2_linked_coord->{original}) eq 'Bio::EnsEMBL::Mapper::Gap' ) { #gaps do not have coordinates in the seqs. so we romove then
                    next;
                }
                my $ga2_aln_coord = $ga2_linked_coord->{original}; #returns the ga2 aln coords
                my @ga1_aln_links = $ga1_mapper->map_coordinates('ALIGNMENT',$ga2_aln_coord->{start}, $ga2_aln_coord->{end}, $strand,'alignment',$include_original_region); #map the alignment coordinates from the ga2 mapper object back to the sequence coordinate of the ga1 genomic_aligns mapper object. This allows us to retrieve genuine 1 to 1 mapped coordinates
                push @mapped_coords, @ga1_aln_links;
            }
        }
        $self->param('mapped_coords', \@mapped_coords);
        my $no_of_aligned_bases = $self->_sum_aligned_bases();
        print "\n no_of_aligned_bases for $gid1 : ", $ga1->dbID, " : $no_of_aligned_bases \n" if ( $self->debug >3 );
        $self->dataflow_output_id({ 'frm_genome_db_id' => $gid1, 'to_genome_db_id' => $gid2, 'no_of_aligned_bases' => $no_of_aligned_bases} ,2); 
    }
}

sub _calculate_duplicate_coverage {
    my ($self,$gid1, $gid2) = @_;
    print "\n we are now in _calculate_duplicate_coverage $gid1 VS $gid2  \n";

    #this next bits are to enable us to create an unknown amount of containers to hold the arrayrefs of the duplicated genomic aligns
    my $no_duplication =  scalar @{$self->param('genomic_aligns_hash')->{$gid2}};
    print "\n below is the genomic aligns for the target genome : $no_duplication \n\n" if ( $self->debug >3 );
    my %duplication_master;
    for ( my $dup = 0; $dup < $no_duplication; $dup++ ) {
        $duplication_master{$dup} = $self->_decompose_cigar($self->param('genomic_aligns_hash')->{$gid2}->[$dup]);
    }
    my @hash_keys = keys %duplication_master;  

    foreach my $ga1 (@{$self->param('genomic_aligns_hash')->{$gid1}}) { #usind foreach loop because there can be more than one genomic align 
        print " \n ref start ", $ga1->dnafrag_start, " ref end " , $ga1->dnafrag_end, "  = ", ($ga1->dnafrag_end-$ga1->dnafrag_start), " \n\n" if ( $self->debug >3 );
        my $ga1_cigar_arrayref = $self->_decompose_cigar($ga1);
#        print Dumper($ga1_cigar_arrayref) , "\n ga1 cigar array \n";
        my %duplication = %{dclone (\%duplication_master)}; #we need to create a copy as we will be messing with this hash
        #now we do the calculation of the aligned position. between the souce genomic align and the duplication genomic. A match for a single position can only be recorded once even if that position is matched in multiple duplicated genomic aligns
        my $aligned_base_positions =0;
        my $temp_counter =0;
        while (scalar(@{$ga1_cigar_arrayref})) {
#            print Dumper($ga1_cigar_arrayref->[0]), " \n <<<------ source \n";
            $temp_counter++;
            if ( $ga1_cigar_arrayref->[0]->[0] eq 'M' ) {
                foreach my $duplicated_ga_id (@hash_keys) {
                    if ($duplication{$duplicated_ga_id}->[0]->[0] eq 'M') {
                        $aligned_base_positions++;
                        last; #only one of the duplicated genomic aligns need to me base matched to our source
                    }
                }
            }

            #now we need to prune the cigar line arrays before the next iteration
            $ga1_cigar_arrayref->[0]->[1]--;
            if ($ga1_cigar_arrayref->[0]->[1] == 0) {
                shift (@{$ga1_cigar_arrayref});
            }
            #we also neeed to prune the duplicated ga cigar line arrays
            foreach my $dup_ga_id (@hash_keys) {
#                print Dumper($duplication{$dup_ga_id}->[0]), " \n <<<------ targets \n";
                $duplication{$dup_ga_id}->[0]->[1]--;
                if ($duplication{$dup_ga_id}->[0]->[1] == 0){
                    shift(@{$duplication{$dup_ga_id}});
                }
            }
        }
        print "\nthis is currently aligned_base_positions : $aligned_base_positions  \n  this is the lenght of the expanded cigar line : $temp_counter \n\n" if ( $self->debug >3 );
        $self->dataflow_output_id({ 'frm_genome_db_id' => $gid1, 'to_genome_db_id' => $gid2, 'no_of_aligned_bases' => $aligned_base_positions} ,2);    
    }   
}

sub _sum_aligned_bases {
    my $self = shift;
    my $aligned_bases = $self->param('mapped_coords');
#    print Dumper($aligned_bases);
    print "we are now in _sum_aligned_bases \n";
    my $sum_of_bases=0;
    foreach my $mapped_pair (@{$aligned_bases}) {
        $sum_of_bases += ($mapped_pair->{mapped}->{end} - $mapped_pair->{mapped}->{start}) 
    }
    return $sum_of_bases;
}



1;
