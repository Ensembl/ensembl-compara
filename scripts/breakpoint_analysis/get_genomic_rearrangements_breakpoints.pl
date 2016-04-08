#!/usr/bin/env perl

=pod

=head1 DESCRIPTION
 
 This script finds the number of collinear genomic blocks in an alignment. Information about the blocks are written to the given output file (this files tend to be 20mb and upwards in size).
 The threshold is used to determined 1: if a block is a non colinear block is big enough to be a valid breakpoint in the the genome and 2: if a block or colinear blocks should be printed to the output file.
 Also inversion bigger than the threshold are reported as breakpoints.
 To run this script, you need to give it the following

    -reg_conf  -> The registry configuration file which contains infomation on where to find and how to connect to the alignment database

    -species1   -> the reference species

    -species2   -> non reference species

    -kb   -> the size of the threshold in kilobase

    -output     -> output file  format : -> ref_chr_id,ref_start,ref_end,nonref_chr_id,non_ref_start,nonref_end, genomic_block_ids
    -debug      -> if you want the debug statements printed to the screen
    example run : perl get_genomic_rearrangements_breakpoints.pl -species1 mus_caroli -species2 mus_pahari -kb 10 -output trial_b -reg_conf /nfs/users/nfs_w/wa2/Mouse_rearrangement_project/mouse_reg_livemirror_03_16.conf


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
my ( $reg_conf, $ref, $non_ref, $base, $output1_file, $debug);
GetOptionsFromArray(
    \@ARGV,
    'reg_conf=s'    => \$reg_conf,
    'species1=s'    => \$ref,
    'species2=s'    => \$non_ref,
    'kb=i'          => \$base,
    'output=s'      => \$output1_file,
    'debug=i'       => \$debug

);

$| = 1;


$reg_conf ||= '/nfs/users/nfs_w/wa2/Mouse_rearrangement_project/mouse_reg_livemirror_03_16.conf';
die("Please provide species of interest (-species1 & -species2) and the minimum alignment block size (-base) and output files (-output) ") unless( defined($ref) && defined($non_ref)&& defined($base)&& defined($output1_file) );
die("\nThe given output file already exists\n") if -e $output1_file;
my $kilobase = $base * 1000; #megabase

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");

my $mlss_adap  = $registry->get_adaptor( 'mice_merged', 'compara', 'MethodLinkSpeciesSet' );
my $gblock_adap = $registry->get_adaptor( 'mice_merged', 'compara', 'GenomicAlignBlock' );
my $GDB_adaptor = $registry->get_adaptor( 'mice_merged', 'compara', 'GenomeDB' );
#my $mlss_adap  = $registry->get_adaptor( 'Multi', 'compara', 'MethodLinkSpeciesSet' );
#my $gblock_adap = $registry->get_adaptor( 'Multi', 'compara', 'GenomicAlignBlock' );
#my $GDB_adaptor = $registry->get_adaptor( 'Multi', 'compara', 'GenomeDB' );
my $mlss = $mlss_adap->fetch_by_method_link_type_registry_aliases( "LASTZ_NET", [ $ref, $non_ref ] );
print $mlss->dbID(), " mlssssssssssssssssss idddddddddddd \n" if ($debug) ;

#print STDOUT "\n getting all genomic blocks for the given pair of species \n";
my @gblocks = @{ $gblock_adap->fetch_all_by_MethodLinkSpeciesSet( $mlss ) };

my %gblocks_hash; #will contain the rat chr number as keys mapping to an hash table of all of the genomic aln block of that chr as values. 

my $whole_gblocks_hash_ref ={}; # so that i will be able to use the string form of the genomic aln block to get back the objects
#print $GDB_adaptor, "   the adaptor \n the genome   ", $GDB_adaptor->fetch_by_name_assembly($ref), "\n";
my $ref_gdbID = $GDB_adaptor->fetch_by_name_assembly($ref)->dbID();
my $non_ref_gdbID = $GDB_adaptor->fetch_by_name_assembly($non_ref)->dbID();
print "ref gbid ", $ref_gdbID , "   non ref gb id ", $non_ref_gdbID , "\n\n"  if ($debug) ;

print STDOUT "\n partition genomic blocks into an hash based on the reference species chromosomes \n" if ($debug) ;
my $count = 0;
while ( my $gblock = shift @gblocks ) { 
    my $ref_gns= $gblock->get_all_GenomicAligns([$ref_gdbID])->[0];
#    print $ref_gns->dnafrag->genome_db->name, " ref hahahahahaha\n\n\n";
    my $dnafrag_id = $ref_gns->dnafrag()->name(); #ref species galigns dnafrag id
    $gblocks_hash{$dnafrag_id}{$gblock} = $ref_gns->dnafrag_start();
    $whole_gblocks_hash_ref->{$gblock}=$gblock;
    $count ++;
#	if ($count == 50){
#        print STDOUT "Starting part 22222222222222222222222222222 \n";
#		print Dumper(\%gblocks_hash);
#		last;
#	}

}
#loop through each chr hash table and determine if there are collinear alignment block that can be merged.
#if there collinear blocks , merge them, create a new hash table for the chr with the reformatted alignment blocks i.e. grouping merged blocks together. 
#my $merged_hash_ref={};
#open(OUT1, '>', $output1_file);
#my $result_inner_hash_ref = {};

my @ref_chrs = keys %gblocks_hash;
print "  2222222222222222222222222222    number of gblocks:   $count \n";
my $counter;
open my $OUT1, '>', $output1_file or die "Could not open file '$output1_file' $!";
#print STDOUT scalar @keys, "\n\n\n";
my $invert = 0;
while (my $ref_chr = shift (@ref_chrs)) {
    print " The start of the mainnnnnnnnnnnnn while loop \n" if ($debug) ;
#    print STDOUT $counter--, "\n\n";
#    print $ref_chr, "hhhhhhhhhhhh\n\n";
    my $gbs_hash_ref = $gblocks_hash{$ref_chr};
#    print STDOUT "Starting part 22222222222222222222222222222 \n";
#    print Dumper($gbs_hash_ref);
    # if the chr contains only one genomic alns block then there is not need to sort it, hence it can be added directly to the $merged_hash_ref
    my @gbs = keys %$gbs_hash_ref;
    if (scalar @gbs ==1){

#       print "chr contains only one block \n\n";
#       $merged_hash_ref->{$key}{$nonref_chr_hash_keys} = {};
        print_result($whole_gblocks_hash_ref, \@gbs, $ref_chr, $OUT1);
        next;
    }

    my @chr_gblocks_sorted; # will contain the genomic aln block ordered by the dnafrag start position
    #sorting the genomic alns block by dnafrag start position
    foreach my $name (sort { int($gbs_hash_ref->{$a}) <=> int($gbs_hash_ref->{$b}) or $a cmp $b } keys %$gbs_hash_ref ) {
    
#            printf "%-8s %s \n", $name, $gbs_hash_ref->{$name};
        push @chr_gblocks_sorted, $name;

    }
#    print STDOUT "Starting part 22222222222222222222222222222 \n";
#    print Dumper(@chr_gblocks_sorted);
    my (@merged, %already_merged, $default_non_ref_strand, $default_non_ref_gns_chrom);
    my $left2do_index=0;
    my $left_to_do = 1;

    while ($left_to_do) {
        print "\n       back to the start of the while loop,  this is the value of left2do_index  ---   $left2do_index  \n" if ($debug) ;
        $left_to_do = 0;
        for (my $pos = $left2do_index; $pos < scalar @chr_gblocks_sorted; $pos++) {
            print "\n   back in for loooooooooooop             $pos    \n  this is merged!!!" if ($debug) ;
            print Dumper(@merged) if ($debug) ;
            my $current_non_ref_gns0 = $whole_gblocks_hash_ref->{$chr_gblocks_sorted[$pos]}->get_all_GenomicAligns([$non_ref_gdbID])->[0];
            my $current_ref_gns0 = $whole_gblocks_hash_ref->{$chr_gblocks_sorted[$pos]}->get_all_GenomicAligns([$ref_gdbID])->[0];

            if (@merged) {
                if (($default_non_ref_gns_chrom ne $current_non_ref_gns0->dnafrag()->name()) 
                   || ($default_non_ref_strand !=$current_non_ref_gns0->dnafrag_strand())) {
                    print "possible break pointttttttttttt \n" if ($debug) ;
                    #smaller than the threshold
                    if ($whole_gblocks_hash_ref->{$chr_gblocks_sorted[$pos]}->length < $kilobase) {
                        print "smallerrrrr than threshold $kilobase       ", $whole_gblocks_hash_ref->{$chr_gblocks_sorted[$pos]}->length, "   \n" if ($debug) ;
                        #if not already merged with another block and is the earliest one we have found, we want to start from here on the next iteration of the while loop
                        if ( (!$already_merged{$chr_gblocks_sorted[$pos]} ) && (!$left_to_do) ) {
                            $left_to_do = 1;
                            $left2do_index = $pos;
                        }
                    }
                    #bigger than the threshold
                    else {
                        print "bigger than threshold $kilobase so we print the block    ", $whole_gblocks_hash_ref->{$chr_gblocks_sorted[$pos]}->length, "   \n" if ($debug) ;
                        if ($default_non_ref_strand !=$current_non_ref_gns0->dnafrag_strand()) {
                        	$invert=1;
                        }
                        print_result($whole_gblocks_hash_ref, \@merged, $ref_chr, $OUT1, $invert);
                        $invert = 0;
                        #not already merged with another block, continue the for loop. with the new merged block starting from here
                        if (!$already_merged{$chr_gblocks_sorted[$pos]}) {
                            @merged = $chr_gblocks_sorted[$pos];
                            $default_non_ref_strand = $current_non_ref_gns0->dnafrag_strand();
                            $default_non_ref_gns_chrom = $current_non_ref_gns0->dnafrag()->name();
                        }
                        #skipping the block because it has already been merged
                        else{
                            undef @merged;
                            next;
                        }
                    }
                }
                #merging the block 
                else{
                    push @merged, $chr_gblocks_sorted[$pos];
                    $already_merged{$chr_gblocks_sorted[$pos]} = 1;
                }
            } 
            else {
                #if this is the first time we are running through the loop OR we just jump an already merged block
                if ($already_merged{$chr_gblocks_sorted[$pos]}) {
                        next;
                }
                else {
                push @merged, $chr_gblocks_sorted[$pos];
                $already_merged{$chr_gblocks_sorted[$pos]} = 1;
                $default_non_ref_strand = $current_non_ref_gns0->dnafrag_strand();
                print STDOUT "\n first 11111111111111111111111111111 default_non_ref_strand ,    $default_non_ref_strand  ,  \n" if ($debug) ;
                $default_non_ref_gns_chrom = $current_non_ref_gns0->dnafrag()->name();
                print STDOUT "\n first 11111111111111111111111111111 default_non_ref_gns_chrom  , $default_non_ref_gns_chrom ,  \n" if ($debug) ;
                }
            } 
        }
        print_result($whole_gblocks_hash_ref, \@merged, $ref_chr, $OUT1, $invert); 
        undef @merged; 
    }
}

print "this is the number of breaks we had  , $counter ,   \n" if ($debug) ;
close $OUT1;


sub print_result {
    print "\n       we are in the print resultssssssssssssss     ", $kilobase, "   \n" if ($debug) ;
    my ($local_whole_gblocks_hash_ref, $local_merged_array_ref, $local_ref_chr, $fh, $inverted) = @_;
    my @local_merged = @$local_merged_array_ref;
    my $length = 0;
    if (scalar @local_merged == 1) {
        my $non_ref_gns2 = $local_whole_gblocks_hash_ref->{$local_merged[0]}->get_all_GenomicAligns([$non_ref_gdbID])->[0];
        my $ref_gns2 = $local_whole_gblocks_hash_ref->{$local_merged[0]}->get_all_GenomicAligns([$ref_gdbID])->[0];
        my $length = $local_whole_gblocks_hash_ref->{$local_merged[0]}->length();
        if ($length >= $kilobase) {
            print "this is the length of the merged blocks,   $length  , it is bigger than threshold     PRINTING IT TO FILE NOW   \n" if ($debug) ;
            my $start = $ref_gns2->dnafrag_start();
            my $end = $ref_gns2->dnafrag_end();
            my $non_ref_start = $non_ref_gns2->dnafrag_start();
            my $non_ref_end = $non_ref_gns2->dnafrag_end();
            my $non_ref_chr = $non_ref_gns2->dnafrag_id();
            if ($inverted){
            	print $fh $local_ref_chr, "\t\t", $start ,"\t\t", $end, "\t\t", $non_ref_chr, "\t\t", $non_ref_start, "\t\t", $non_ref_end, "\n", $local_whole_gblocks_hash_ref->{$local_merged[0]}->dbID(),"\n/--/\n";
            	$counter ++;
            }
            else{
            	print $fh $local_ref_chr, "\t\t", $start ,"\t\t", $end, "\t\t", $non_ref_chr, "\t\t", $non_ref_start, "\t\t", $non_ref_end, "\n", $local_whole_gblocks_hash_ref->{$local_merged[0]}->dbID(),"\n//\n";
            	$counter ++;
            }
        }
    }
    else{

        #find the total length of the merged blocks
        my $galigns;
        foreach my $gbk (@local_merged ) {
#            my $non_ref_gns3 = $local_whole_gblocks_hash_ref->{$gbk}->get_all_GenomicAligns([$non_ref_gdbID])->[0];
#            my $ref_gns3 = $local_whole_gblocks_hash_ref->{$gbk}->get_all_GenomicAligns([$ref_gdbID])->[0];
            $length += $local_whole_gblocks_hash_ref->{$gbk}->length();

        }
        print "this is the length of the merged blocksssss     ", $length, "        \n\n" if ($debug) ;
        
        #find the extreme start and extreme end of the the blocks.
        if ($length >= $kilobase) { 
            print "555555555555555555555555555555555555555 merged block it is bigger than threshold... PRINTING IT TO FILE NOW \n" if ($debug) ;
            my $start=2000000000000000000000; 
            my $end=0;
            my $non_ref_start= 2000000000000000000000;
            my $non_ref_end=0;
            my $non_ref_chr=$local_whole_gblocks_hash_ref->{$local_merged[0]}->get_all_GenomicAligns([$non_ref_gdbID])->[0]->dnafrag()->name();
            my $block_ids;

# ******* if the lenght of @merged is greater than threshold, then i will loop through @merged twice. STILL HAVE TO THINK OF A WAY TO LOOP THROUGH IT Only ONCE.
            foreach my $gbk (@local_merged) {
#               print $gbk , "kkkkkkkkkk\n";
                $block_ids .= "\t" . $local_whole_gblocks_hash_ref->{$gbk}->dbID();
                my $non_ref_gns4 = $local_whole_gblocks_hash_ref->{$gbk}->get_all_GenomicAligns([$non_ref_gdbID])->[0];
                my $ref_gns4 = $local_whole_gblocks_hash_ref->{$gbk}->get_all_GenomicAligns([$ref_gdbID])->[0];

                if ($start > $ref_gns4->dnafrag_start()){
                    $start = $ref_gns4->dnafrag_start();
                }

                if ($end < $ref_gns4->dnafrag_end()){
                    $end = $ref_gns4->dnafrag_end();
                }

                if ($non_ref_start > $non_ref_gns4->dnafrag_start()){
                    $non_ref_start = $non_ref_gns4->dnafrag_start();
                }

                if ($non_ref_end < $non_ref_gns4->dnafrag_end()){
                    $non_ref_end = $non_ref_gns4->dnafrag_end();
                }
            }
            if ($inverted){
	            print $fh $local_ref_chr, "\t\t", $start ,"\t\t", $end, ,"\t\t",$non_ref_chr,"\t\t",$non_ref_start ,"\t\t",$non_ref_end,"\n",$block_ids,"\n/--/\n";
    	        $counter ++;
    	    }
    	    else{
    	    	print $fh $local_ref_chr, "\t\t", $start ,"\t\t", $end, ,"\t\t",$non_ref_chr,"\t\t",$non_ref_start ,"\t\t",$non_ref_end,"\n",$block_ids,"\n//\n";
    	        $counter ++;
    	    }
        } 
    }
}

POSIX::_exit(0);
