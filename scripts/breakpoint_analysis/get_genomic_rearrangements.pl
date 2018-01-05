#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


=pod

=head1 DESCRIPTION
 
 This script finds the number of collinear genomic blocks in an alignment. Information about the blocks are written to the given output file (this files tend to be 20mb and upwards in size).
 The threshold is used to determined 1: if a block is a non colinear block is big enough to be a valid breakpoint in the the genome and 2: if a block or colinear blocks should be printed to the output file.
 Also inversion bigger than the threshold are reported as breakpoints.
 To run this script, you need to give it the following

    -reg_conf  -> The registry configuration file which contains infomation on where to find and how to connect to the alignment database

    -species1   -> the reference species

    -species2   -> non reference species

    -EPO		-> set if yoiu want the breakpoints from the EPO alignments

    -threshold   -> the size of the threshold in kilobase
	
	-DB_species	-> the species name of the database (usually 'MULTI' for ensembl production dbs)
    -output     -> output file  format : -> ref_chr_id,ref_start,ref_end,nonref_chr_id,non_ref_start,nonref_end, genomic_block_ids
    -debug      -> if you want the debug statements printed to the screen
    example run : perl get_genomic_rearrangements.pl -species1 mus_caroli -species2 mus_pahari -threshold 10 -DB_species <mice_merged> -EPO <0/1> -output trial_b -reg_conf /nfs/users/nfs_w/wa2/Mouse_rearrangement_project/mouse_reg_livemirror_03_16.conf


=cut

use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Bio::AlignIO;
use Getopt::Long qw(GetOptionsFromArray);
use Data::Dumper;
use POSIX qw[ _exit ];
my $start_run = time();
# OPTIONS
my ( $reg_conf, $ref, $non_ref, $kilobase, $output1_file, $debug, $DB_species, $EPO);
GetOptionsFromArray(
    \@ARGV,
    'reg_conf=s'    => \$reg_conf,
    'species1=s'    => \$ref,
    'species2=s'    => \$non_ref,
    'threshold=i'   => \$kilobase,
    'output=s'      => \$output1_file,
    'DB_species=s'	=> \$DB_species,
    'debug=i'       => \$debug,
    'EPO=i'			=> \$EPO
);

$| = 1 if ($debug);


$reg_conf ||= '/nfs/users/nfs_w/wa2/Mouse_rearrangement_project/mouse_reg_livemirror_03_16.conf';
$DB_species ||= 'Multi';
die("Please provide species of interest (-species1 & -species2) and the minimum alignment block size (-threshold) and output files (-output) ") unless( defined($ref) && defined($non_ref)&& defined($kilobase)&& defined($output1_file) );
die("\nThe given output file already exists\n") if -e $output1_file;
my $threshold = $kilobase * 1000; #convert 5kb to 5000b

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");

my $mlss_adap   = $registry->get_adaptor( $DB_species, 'compara', 'MethodLinkSpeciesSet' );
my $gblock_adap = $registry->get_adaptor( $DB_species, 'compara', 'GenomicAlignBlock' );
my $GDB_adaptor = $registry->get_adaptor( $DB_species, 'compara', 'GenomeDB' );

my ($mlss,$ref_gdbID,$non_ref_gdbID, @gblocks);
my %gblocks_hash; #will contain the chr number as keys mapping to an hash table of all of the genomic aln block of that chr as values. 
my $whole_gblocks_hash_ref ={}; # so that i will be able to use the string form of the genomic aln block to get back the objects


if ($EPO) {
    print STDOUT "\n        This breakpoints are from an EPO Alignment        \n" ;
	my $dnafrag_adaptor = $registry->get_adaptor( $DB_species, 'compara', 'DnaFrag' );
	$mlss =  $mlss_adap->fetch_by_method_link_type_species_set_name( 'EPO', 'collection-mammals_with_mouse' );
	my $ref_gdb = $GDB_adaptor->fetch_by_name_assembly($ref);
	my $non_ref_gdb = $GDB_adaptor->fetch_by_name_assembly($non_ref);
	my @dnafrags_sp1 = @{ $dnafrag_adaptor->fetch_all_by_GenomeDB_region( $ref_gdb, 'chromosome' ) };
	my @dnafrags_sp2 = @{ $dnafrag_adaptor->fetch_all_by_GenomeDB_region( $non_ref_gdb, 'chromosome' ) };

	$ref_gdbID = $ref_gdb->dbID();
 	$non_ref_gdbID = $non_ref_gdb->dbID();

	foreach my $sp1_dnafrag ( @dnafrags_sp1 ) {
    	foreach my $sp2_dnafrag ( @dnafrags_sp2 ) {
        	my $genomic_align_blocks = $gblock_adap->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag( $mlss, $sp1_dnafrag, undef, undef, $sp2_dnafrag, undef, undef );
        	push( @gblocks, @{ $genomic_align_blocks } );
    	}
	}
}
else{
    print STDOUT "\n        This breakpoints are from a LASTZ_NET Alignment        \n" ;
	$mlss = $mlss_adap->fetch_by_method_link_type_registry_aliases( "LASTZ_NET", [ $ref, $non_ref ] );
	#getting all genomic blocks for the given pair of species
	@gblocks = @{ $gblock_adap->fetch_all_by_MethodLinkSpeciesSet( $mlss ) };
	$ref_gdbID = $GDB_adaptor->fetch_by_name_assembly($ref)->dbID();
	$non_ref_gdbID = $GDB_adaptor->fetch_by_name_assembly($non_ref)->dbID();
}
 
warn $mlss->dbID(), "      mlss id     \n" if ($debug) ;
print "ref gbid ", $ref_gdbID , "   non ref gb id ", $non_ref_gdbID , "\n\n"  if ($debug) ;

print STDOUT "\n partition genomic blocks into an hash based on the reference species chromosomes \n" if ($debug) ;
my $count = 0;
while ( my $gblock = shift @gblocks ) { 
    my $ref_gns= $gblock->get_all_GenomicAligns([$ref_gdbID])->[0];
    my $dnafrag_id = $ref_gns->dnafrag()->dbID; #ref species galigns dnafrag id
    $gblocks_hash{$dnafrag_id}{$gblock->dbID} = $ref_gns->dnafrag_start();
    $whole_gblocks_hash_ref->{$gblock->dbID}=$gblock;
    $count ++;
#	if ($count == 100){
#        print STDOUT "This is the entire gblocks  \n";
#		print Dumper(\%gblocks_hash);
#		last;
#	}

}


#loop through each chr hash table and determine if there are collinear alignment block that can be merged.
#if there collinear blocks , merge them, create a new hash table for the chr with the reformatted alignment blocks i.e. grouping merged blocks together. 

my @ref_chrs = keys %gblocks_hash;
print STDOUT "    The total number of gblocks  :   $count \n";
my $counter;
open my $OUT1, '>', $output1_file or die "Could not open file '$output1_file' $!";
#print STDOUT scalar @keys, "\n\n\n";
my $invert = 0;
my %merged_hash;
while (my $ref_chr = shift (@ref_chrs)) {
    print "    The start of the main while loop    \n" if ($debug) ;
    my $gbs_hash_ref = $gblocks_hash{$ref_chr};

    # if the chr contains only one genomic alns block then there is not need to sort it, hence it can be added directly to the $merged_hash_ref
    my @gbs = keys %$gbs_hash_ref;
    if (scalar @gbs ==1){
    	update_merged_blocks($gbs[0]);
        check_threshold();
        next;
    }

	#sorting the genomic alns block by dnafrag start position
    my @chr_gblocks_sorted = sort { $gbs_hash_ref->{$a} <=> $gbs_hash_ref->{$b} } keys %$gbs_hash_ref; # will contain the genomic aln block ordered by the dnafrag start position
    
    #loop through the sorted gblocks to find breakpoints
    my (%already_merged_hash, $default_non_ref_strand, $default_non_ref_gns_chrom);
   
    my $left2do_index=0;
    #the engine. this for loop is responsible for finding block that can be merged. 
    #it will keep merging blocks till a block that is bigger than the threshold whose chromosome or strand dont match is found.
    #if a block that is smaller than the threshold whose chromosome or strand do not match is found we do not merge this block (save it for later) but we skip over it and see if the next block be merged 
    for (my $pos = $left2do_index; $pos < scalar @chr_gblocks_sorted; $pos++) {
        print "\n   back in for loop. this is our current position:    $pos    \n    this is merged!!!" if ($debug) ;
        print Dumper($merged_hash{'blocks'}) if ($debug) ;
        my $current_non_ref_gns0 = $whole_gblocks_hash_ref->{$chr_gblocks_sorted[$pos]}->get_all_GenomicAligns([$non_ref_gdbID])->[0];
        my $current_ref_gns0 = $whole_gblocks_hash_ref->{$chr_gblocks_sorted[$pos]}->get_all_GenomicAligns([$ref_gdbID])->[0];

        if ($merged_hash{'blocks'}) {
           	if (($default_non_ref_gns_chrom ne $current_non_ref_gns0->dnafrag_id()) 
                || ($default_non_ref_strand !=$current_non_ref_gns0->dnafrag_strand())) {
                print "     possible break point   \n" if ($debug) ;
                #smaller than the threshold
                if ($whole_gblocks_hash_ref->{$chr_gblocks_sorted[$pos]}->length < $threshold) {
                    print "smallerrrrr than threshold $threshold       : ", $whole_gblocks_hash_ref->{$chr_gblocks_sorted[$pos]}->length, "   \n" if ($debug) ;
                    #if not already merged with another block and is the earliest one we have found, we want to start from here on the next iteration of the while loop
                    if ( (!$already_merged_hash{$chr_gblocks_sorted[$pos]} ) && (!$left2do_index) ) {
                        $left2do_index = $pos;
                    }
                }
                #bigger than the threshold
                else {
                    print "bigger than threshold $kilobase so we print the block  : ",  $whole_gblocks_hash_ref->{$chr_gblocks_sorted[$pos]}->length, "  \n" if ($debug) ;
                    #check if this break was cause by an inversion
                    if ($default_non_ref_strand !=$current_non_ref_gns0->dnafrag_strand()) {
                        $invert=1;
                    }

                    check_threshold();
                    $invert = 0;

                    #if we have already skipped over some blocks now we go back to where they are
                    if ($left2do_index) {
                        print "   yes we have skipped over thing let go back       current pos :  $pos    skipped pos :    $left2do_index\n" if ($debug) ;
                        $pos = $left2do_index -1;
                        $left2do_index = 0;
                        next;
                    }
                    #not already merged with another block, continue the for loop. with the new merged block starting from here
                    elsif (!$already_merged_hash{$chr_gblocks_sorted[$pos]}) {
                        update_merged_blocks($chr_gblocks_sorted[$pos]);
                        $default_non_ref_strand = $current_non_ref_gns0->dnafrag_strand();
                        $default_non_ref_gns_chrom = $current_non_ref_gns0->dnafrag_id();
                    }
                    #skipping the block because it has already been merged
                    else{
                        next;
                    }
                }
            }
            #merging the block 
            else{
                update_merged_blocks($chr_gblocks_sorted[$pos]);
                $already_merged_hash{$chr_gblocks_sorted[$pos]} = 1;
            }
        }
            #if this is the first time we are running through the loop OR we just jump an already merged block
        elsif ($already_merged_hash{$chr_gblocks_sorted[$pos]}) {
            next;
        }
        else {
            update_merged_blocks($chr_gblocks_sorted[$pos]);
            $already_merged_hash{$chr_gblocks_sorted[$pos]} = 1;
            $default_non_ref_strand = $current_non_ref_gns0->dnafrag_strand();
            print STDOUT "\n first default_non_ref_strand ,    $default_non_ref_strand    \n" if ($debug) ;
            $default_non_ref_gns_chrom = $current_non_ref_gns0->dnafrag_id();
            print STDOUT "\n first default_non_ref_gns_chrom  , $default_non_ref_gns_chrom  \n" if ($debug) ;
        }

        #when we get the end of the loop, we need to check if we had skipped over any blocks before we exit the loop completely.
        if ($pos == scalar @chr_gblocks_sorted-1) {
           	check_threshold(); 
          	
          	if ($left2do_index) {
            	print "   we are at the end but yes we have skipped over thing let go back       current pos :  $pos    skipped pos :    $left2do_index\n" if ($debug) ;
            	$pos = $left2do_index -1;
            	$left2do_index = 0;
            	next;
        	}
        }
    }
}


print "this is the number of breaks we had  , $counter   \n" if ($debug) ;
close $OUT1;


sub update_merged_blocks{
	print "   \n    we are in the 'update_merged_blocks' subroutine \n" if ($debug) ;
	my ($block) = @_;
	my $non_ref_gns = $whole_gblocks_hash_ref->{$block}->get_all_GenomicAligns([$non_ref_gdbID])->[0];
    my $ref_gns = $whole_gblocks_hash_ref->{$block}->get_all_GenomicAligns([$ref_gdbID])->[0];
    my $ref_start = $ref_gns->dnafrag_start() ;
    my $ref_end = $ref_gns->dnafrag_end();
    my $ref_chr = $ref_gns->dnafrag_id();
    my $non_ref_start = $non_ref_gns->dnafrag_start();
    my $non_ref_end = $non_ref_gns->dnafrag_end();
    my $non_ref_chr = $non_ref_gns->dnafrag_id();
    my $length = $whole_gblocks_hash_ref->{$block}->length();

	if (%merged_hash) {
		push $merged_hash{'blocks'}, $block;
		$merged_hash{'length'} += $length;

		if ($merged_hash{'ref_start'} > $ref_start) {
			$merged_hash{'ref_start'} = $ref_start;
		}

		if ($merged_hash{'ref_end'} < $ref_end) {
			$merged_hash{'ref_end'} = $ref_end;
		}

		if ($merged_hash{'non_ref_start'} > $non_ref_start) {
			$merged_hash{'non_ref_start'} = $non_ref_start;
		}

		if ($merged_hash{'non_ref_end'} < $non_ref_end) {
			$merged_hash{'non_ref_end'} = $non_ref_end;
		}

	}
	else {
		$merged_hash{'blocks'} = [$block];
		$merged_hash{'length'} = $length;
		$merged_hash{'ref_start'} = $ref_start;
		$merged_hash{'ref_end'} = $ref_end;
		$merged_hash{'ref_chr'} = $ref_chr;
		$merged_hash{'non_ref_start'} = $non_ref_start;
		$merged_hash{'non_ref_end'} = $non_ref_end;
		$merged_hash{'non_ref_chr'} = $non_ref_chr;
	}
}

sub check_threshold {
	print "   \n    we are in the check threshold subroutine     \n" if ($debug) ;


	if ($merged_hash{'length'} >= $threshold) {
		print_result();
	}
	undef %merged_hash;
}

sub print_result {
    print "\n       we are in the print result subroutine   size:    $merged_hash{'length'} \n" if ($debug) ;
  	
  	my $blocks_str = join("\t", @{$merged_hash{'blocks'}});
    if ($invert){
	    print $OUT1 join ("\t\t", $merged_hash{'ref_chr'}, $merged_hash{'ref_start'} , $merged_hash{'ref_end'},  
	    	$merged_hash{'non_ref_chr'}, $merged_hash{'non_ref_start'}, $merged_hash{'non_ref_end'}, $blocks_str);
	    print $OUT1 "\n/--/\n";
    	$counter ++;
    }
    else{
    	print $OUT1 join ("\t\t", $merged_hash{'ref_chr'}, $merged_hash{'ref_start'} , $merged_hash{'ref_end'},  
	    	$merged_hash{'non_ref_chr'}, $merged_hash{'non_ref_start'}, $merged_hash{'non_ref_end'}, $blocks_str);
	    print $OUT1 "\n//\n";
    	$counter ++;
    }
         
    
}

POSIX::_exit(0);
