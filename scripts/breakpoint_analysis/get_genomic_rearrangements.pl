#!/usr/bin/env perl

=pod

=head1 DESCRIPTION
 
 This script finds the number of collinear genomic blocks in an alignment. Information about the blocks are written to the given output file (this files tend to be 20mb and upwards in size).
 The threshold is used to determined the acceptable distance between two genomic align blocks before we check if they are colinear. Also only merged blocks/block longer than the given threshold are reported.
 To run this script, you need to give it the following

    -reg_conf  -> The registry configuration file which contains infomation on where to find and how to connect to the alignment database

    -species1   -> the reference species

    -species2   -> non reference species

    -kb   -> the size of the threshold in kilobase

    -output     -> output file  format : -> ref_chr_id,ref_start,ref_end,nonref_chr_id,non_ref_start,nonref_end, genomic_block_ids

    example run : perl get_genomic_rearrangements.pl -species1 mus_caroli -species2 mus_pahari -kb 10 -output trial_b -reg_conf /nfs/users/nfs_w/wa2/Mouse_rearrangement_project/mouse_reg_livemirror.conf


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
my ( $reg_conf, $ref, $non_ref, $base, $output1_file);
GetOptionsFromArray(
    \@ARGV,
    'reg_conf=s'   => \$reg_conf,
    'species1=s'         => \$ref,
    'species2=s'         => \$non_ref,
    'kb=i'            => \$base,
    'output=s'   => \$output1_file

);

$| = 1;


$reg_conf ||= '/nfs/users/nfs_w/wa2/Mouse_rearrangement_project/mouse_reg_livemirror.conf';
die("Please provide species of interest (-species1 & -species2) and the minimum alignment block size (-base) and output files (-o1) ") unless( defined($ref) && defined($non_ref)&& defined($base)&& defined($output1_file) );

my $kilobase = $base * 1000;

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");

my $mlss_adap  = $registry->get_adaptor( 'mice_merged', 'compara', 'MethodLinkSpeciesSet' );
my $gblock_adap = $registry->get_adaptor( 'mice_merged', 'compara', 'GenomicAlignBlock' );
my $GDB_adaptor = $registry->get_adaptor( 'mice_merged', 'compara', 'GenomeDB' );
#my $mlss_adap  = $registry->get_adaptor( 'Multi', 'compara', 'MethodLinkSpeciesSet' );
#my $gblock_adap = $registry->get_adaptor( 'Multi', 'compara', 'GenomicAlignBlock' );
#my $GDB_adaptor = $registry->get_adaptor( 'Multi', 'compara', 'GenomeDB' );
my $mlss = $mlss_adap->fetch_by_method_link_type_registry_aliases( "LASTZ_NET", [ $ref, $non_ref ] );
#print STDOUT "Starting part 22222222222222222222222222222 \n";
#print $mlss, " mlssssssssssssssssss\n";
my @gblocks = @{ $gblock_adap->fetch_all_by_MethodLinkSpeciesSet( $mlss ) };

my %gblocks_hash; #will contain the rat chr number as keys mapping to an hash table of all of the genomic aln block of that chr as values. 

my $whole_gblocks_hash_ref ={}; # so that i will be able to use the string form of the genomic aln block to get back the objects
#print $GDB_adaptor, "   the adaptor \n the genome   ", $GDB_adaptor->fetch_by_name_assembly($ref), "\n";
my $ref_gdbID = $GDB_adaptor->fetch_by_name_assembly($ref)->dbID();
my $non_ref_gdbID = $GDB_adaptor->fetch_by_name_assembly($non_ref)->dbID();
#print "ref gbid ", $ref_gdbID , "   non ref gb id ", $non_ref_gdbID , "\n\n";
#separate gblocks in hashes composed of blocks on the same chromosome
my $count = 0;
while ( my $gblock = shift @gblocks ) { 
    my $ref_gns= $gblock->get_all_GenomicAligns([$ref_gdbID])->[0];
#    print $ref_gns->dnafrag->genome_db->name, " ref hahahahahaha\n\n\n";
    my $dnafrag_id = $ref_gns->dnafrag()->name(); #ref species galigns dnafrag id
    my $non_ref_gns = $gblock->get_all_GenomicAligns([$non_ref_gdbID])->[0];
#    print $non_ref_gns->dnafrag->genome_db->name, " non ref hahahahahaha\n\n\n";
    $gblocks_hash{$dnafrag_id}{$non_ref_gns->dnafrag()->name()}{$gblock} = $ref_gns->dnafrag_start();
    $whole_gblocks_hash_ref->{$gblock}=$gblock;
    $count ++;
#	if ($count == 40){
#        print STDOUT "Starting part 22222222222222222222222222222 \n";
#		print Dumper(\%gblocks_hash);
#		last;
#	}
#die;
}

#print STDOUT "Starting part 22222222222222222222222222222 \n";
#loop through each chr hash table and determine if there are collinear alignment block that can be merged.
#if there collinear blocks , merge them, create a new hash table for the chr with the reformatted alignment blocks i.e. grouping merged blocks together. 
#my $merged_hash_ref={};
open(OUT1, '>', $output1_file);
#my $result_inner_hash_ref = {};

my $no_of_col_blocks=0; #the numbe of collinear bloks found 
my @keys = keys %gblocks_hash;
my $counter =scalar @keys;
#print STDOUT scalar @keys, "\n\n\n";
while (my $key = shift (@keys)) {
#    print STDOUT $counter--, "\n\n";
#    print $key, "hhhhhhhhhhhh\n\n";
    my $nonref_chr_hash_ref = $gblocks_hash{$key};
    my @nonref_chr_hash_keys = keys %$nonref_chr_hash_ref;
    while (my $nonref_chr_hash_key = shift (@nonref_chr_hash_keys)) {
#        print $nonref_chr_hash_key, "lllllllllllllllll\n\n";
        my $gbs_hash_ref = $nonref_chr_hash_ref->{$nonref_chr_hash_key};
#        print Dumper($gbs_hash_ref);
        
#   print scalar @chr_keys, "hahahahahahahahah\n\n";
    # if the chr contains only one genomic alns block then there is not need to sort it, hence it can be added directly to the $merged_hash_ref
        my @gbs = keys %$gbs_hash_ref;
        if (scalar @gbs ==1){

#            print "chr contains only one block \n\n";
#        $merged_hash_ref->{$key}{$nonref_chr_hash_keys} = {};
            my $non_ref_gns1 = $whole_gblocks_hash_ref->{$gbs[0]}->get_all_GenomicAligns([$non_ref_gdbID])->[0];
            my $ref_gns1 = $whole_gblocks_hash_ref->{$gbs[0]}->get_all_GenomicAligns([$ref_gdbID])->[0];
            my $length = $ref_gns1->length();

            if ($length > $kilobase) {
                my $start = $ref_gns1->dnafrag_start();
                my $end = $ref_gns1->dnafrag_end();
                my $chr = $ref_gns1->dnafrag()->name();
                my $non_ref_start = $non_ref_gns1->dnafrag_start();
                my $non_ref_end = $non_ref_gns1->dnafrag_end();
                my $non_ref_chr = $non_ref_gns1->dnafrag_id();
                print OUT1 $chr, "\t\t", $start ,"\t\t", $end, "\t\t", $non_ref_chr, "\t\t", $non_ref_start, "\t\t", $non_ref_end, "\n", $whole_gblocks_hash_ref->{$gbs[0]}->dbID(),"\n\n//\n";
                $no_of_col_blocks ++;
#                $result_inner_hash_ref->{$key}{$counter}=[$length,$gbs[0]];
                $counter ++;
            }
            next;
        }

        my @chr_gblocks_sorted; # will contain the genomic aln block ordered by the dnafrag start position
    #sorting the genomic alns block by dnafrag start position
        foreach my $name (sort { int($gbs_hash_ref->{$a}) <=> int($gbs_hash_ref->{$b}) or $a cmp $b } keys %$gbs_hash_ref ) {
    
#            printf "%-8s %s \n", $name, $gbs_hash_ref->{$name};
            push @chr_gblocks_sorted, $name;

        }

        my $remove_ref={};
        while (my $q_gb = shift @chr_gblocks_sorted) {

            next if ( exists $remove_ref->{$q_gb}); 

            my $non_ref_gns0 = $whole_gblocks_hash_ref->{$q_gb}->get_all_GenomicAligns([$non_ref_gdbID])->[0];
            my $ref_gns0 = $whole_gblocks_hash_ref->{$q_gb}->get_all_GenomicAligns([$ref_gdbID])->[0];
        
            my $query_ref_galign_end = $ref_gns0->dnafrag_end();
            my $query_nonref_galign_end = $non_ref_gns0->dnafrag_end();
            my @merged;
            push @merged, $q_gb;
            $remove_ref->{$q_gb} = 1;
            #loop through the rest of the list to extend the merged block
            foreach my $t_gb (@chr_gblocks_sorted) {

                next if ( exists $remove_ref->{$t_gb}); 

                my $non_ref_gns2 = $whole_gblocks_hash_ref->{$t_gb}->get_all_GenomicAligns([$non_ref_gdbID])->[0];
                my $ref_gns2 = $whole_gblocks_hash_ref->{$t_gb}->get_all_GenomicAligns([$ref_gdbID])->[0];
                my $target_ref_galign_start =  $ref_gns2->dnafrag_start();
                my $target_nonref_galign_start =  $non_ref_gns2->dnafrag_start();
#                print $target_ref_galign_start, " target_ref_galign_start and ",  $target_nonref_galign_start, "  target_nonref_galign_start \n";
                my $ref_is_between = (sort {$a <=> $b} $query_ref_galign_end - $kilobase, $query_ref_galign_end + $kilobase, $target_ref_galign_start )[1] == $target_ref_galign_start;
                if ($ref_is_between) {
                    my $nonref_is_between = (sort {$a <=> $b} $query_nonref_galign_end - $kilobase, $query_nonref_galign_end + $kilobase, $target_nonref_galign_start )[1] == $target_nonref_galign_start;
                    if ($nonref_is_between) {
                        push @merged, $t_gb;

                        $query_ref_galign_end = $ref_gns2->dnafrag_end();
                        $query_nonref_galign_end =$non_ref_gns2->dnafrag_end();
                        $remove_ref->{$t_gb} = 1;

                    }
                }
            }

            my $length=0;
            #find the total length of the merged blocks
#            print "this is the merged \n";
#            print Dumper(\@merged);
#            print "NOW going to get the total length of merged  ", scalar @merged, "\n\n\n";
            my $galigns;
            foreach my $gbk (@merged ) {
                my $non_ref_gns3 = $whole_gblocks_hash_ref->{$gbk}->get_all_GenomicAligns([$non_ref_gdbID])->[0];
                my $ref_gns3 = $whole_gblocks_hash_ref->{$gbk}->get_all_GenomicAligns([$ref_gdbID])->[0];
#               print $ref_gns3->length() , " JJJJJJj\n";
                $length += $ref_gns3->length();

            }
            #find the extreme start and extreme end of the the blocks.
            if ($length > $kilobase) { 

                my $start=2000000000000000000000; 
                my $end=0;
                my $chr;
                my $non_ref_start= 2000000000000000000000;
                my $non_ref_end=0;
                my $non_ref_chr;
                my $block_ids;
#           print $temp[0] ,"ggggggggggggg\n";
                foreach my $gbk (@merged) {

#               print $gbk , "kkkkkkkkkk\n";
                    $block_ids .= "\t" . $whole_gblocks_hash_ref->{$gbk}->dbID();
                    my $non_ref_gns4 = $whole_gblocks_hash_ref->{$gbk}->get_all_GenomicAligns([$non_ref_gdbID])->[0];
                    my $ref_gns4 = $whole_gblocks_hash_ref->{$gbk}->get_all_GenomicAligns([$ref_gdbID])->[0];

                    $chr = $ref_gns4->dnafrag()->name();
                    if ($start > $ref_gns4->dnafrag_start()){
                        $start = $ref_gns4->dnafrag_start();
                    }

                    if ($end < $ref_gns4->dnafrag_end()){
                        $end = $ref_gns4->dnafrag_end();
                    }

                    $non_ref_chr = $non_ref_gns4->dnafrag()->name();
                    if ($non_ref_start > $non_ref_gns4->dnafrag_start()){
                        $non_ref_start = $non_ref_gns4->dnafrag_start();
                    }

                    if ($non_ref_end < $non_ref_gns4->dnafrag_end()){
                        $non_ref_end = $non_ref_gns4->dnafrag_end();
                    }

                }
#                print ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>\n\n";
                print OUT1 $chr, "\t\t", $start ,"\t\t", $end, ,"\t\t",$non_ref_chr,"\t\t",$non_ref_start ,"\t\t",$non_ref_end,"\n",$block_ids,"\n\n//\n";
                $no_of_col_blocks ++;
#                unshift @merged, $length;

#                $result_inner_hash_ref->{$key}{$counter}= \@merged; 
#                $counter ++;
#                print Dumper($result_inner_hash_ref);
            }
        }
    }
 #   print Dumper($result_inner_hash_ref);
#    POSIX::_exit(0);
}

close(OUT1);
print STDOUT "Finito!!!! \n $no_of_col_blocks \n\n";
#print Dumper($result_inner_hash_ref);
POSIX::_exit(0);
