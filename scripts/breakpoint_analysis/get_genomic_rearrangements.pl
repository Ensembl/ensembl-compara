=pod

=head1 DESCRIPTION
 
 This script finds the number of collinear genomic blocks in an alignment. Information about the blocks are written to the given output file (this files tend to be 20mb and upwards in size).
 To run this script, you need to give it the following

    -reg_conf  -> The registry configuration file which contains infomation on where to find and how to connect to the alignment database

    -species1   -> the reference species

    -species2   -> non reference species

    -kb   -> the size of the threshold in kilobase

    -output     -> output file  


=cut


#!/usr/bin/env perl
$| = 1;
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



$reg_conf ||= '/nfs/users/nfs_w/wa2/mouse_reg_livemirror.conf';
die("Please provide species of interest (-species1 & -species2) and the minimum alignment block size (-base) and output files (-o1) ") unless( defined($ref) && defined($non_ref)&& defined($base)&& defined($output1_file) );

my $kilobase = $base * 1000;

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf);

my $mlss_adap  = $registry->get_adaptor( 'mice_merged', 'compara', 'MethodLinkSpeciesSet' );
my $gblock_adap = $registry->get_adaptor( 'mice_merged', 'compara', 'GenomicAlignBlock' );

my $mlss = $mlss_adap->fetch_by_method_link_type_registry_aliases( "LASTZ_NET", [ $ref, $non_ref ] );
my @gblocks = @{ $gblock_adap->fetch_all_by_MethodLinkSpeciesSet( $mlss ) };

my %gblocks_hash; #will contain the rat chr number as keys mapping to an hash table of all of the genomic aln block of that chr as values. 

my $whole_gblocks_hash_ref ={}; # so that i will be able to use the string form of the genomic aln block to get back the objects

my $ref_id=0;
my $non_ref_id=1;

#separate gblocks in hashes composed of blocks on the same chromosome
my $count = 0;
while ( my $gblock = shift @gblocks ) { 

	my @galigns = @{ $gblock->get_all_GenomicAligns() };
	my $dnafrag_id = $galigns[$ref_id]->dnafrag()->name();
	#separate gblocks in hashes composed of blocks on the same chromosome
	$gblocks_hash{$dnafrag_id}{$galigns[$non_ref_id]->dnafrag()->name()}{$gblock} = $galigns[$ref_id]->dnafrag_start();
	$whole_gblocks_hash_ref->{$gblock}=$gblock;
	$count ++;

#	if ($count == 5000){
#		print Dumper(\%gblocks_hash);
#		last;
#	}

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

#       print "chr contains only one block \n\n";
#        $merged_hash_ref->{$key}{$nonref_chr_hash_keys} = {};
            my $galigns = $whole_gblocks_hash_ref->{$gbs[0]}->get_all_GenomicAligns();
            my $length = $galigns->[$ref_id]->length();

            if ($length > $kilobase) {
                my $start = $galigns->[$ref_id]->dnafrag_start();
                my $end = $galigns->[$ref_id]->dnafrag_end();
                my $chr = $galigns->[$ref_id]->dnafrag()->name();
                print OUT1 $chr, "\t\t",$length, "\t\t", $start ,"\t\t", $end, "\t\t", $whole_gblocks_hash_ref->{$gbs[0]}->dbID(),"\n\n";
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

            if( exists $remove_ref->{$q_gb}) {
#               print " 111111 yAlreadyyyyyy in remove so skipping ", $gblocks_sorted[$idx], "\n";
                next;
            }
#            print "FIRST while looooooooop", scalar @chr_gblocks_sorted," \n\n";
            my $qgalign_ref = $whole_gblocks_hash_ref->{$q_gb}->get_all_GenomicAligns();
            my $query_ref_galign_end = $qgalign_ref->[$ref_id]->dnafrag_end();
            my $query_nonref_galign_end = $qgalign_ref->[$non_ref_id]->dnafrag_end();
            my @merged;
            push @merged, $q_gb;
            $remove_ref->{$q_gb} = 1;

            foreach my $t_gb (@chr_gblocks_sorted) {

                if( exists $remove_ref->{$t_gb}) {
#                   print " 111111 yAlreadyyyyyy in remove so skipping ", $gblocks_sorted[$idx], "\n";
                    next;
                }
#                print "FOREACH  looooooooop ", scalar @chr_gblocks_sorted, " \n\n";

                my $tgalign_ref = $whole_gblocks_hash_ref->{$t_gb}->get_all_GenomicAligns(); 
                my $target_ref_galign_start =  $tgalign_ref->[$ref_id]->dnafrag_start();
                my $target_nonref_galign_start =  $tgalign_ref->[$non_ref_id]->dnafrag_start();

                my $ref_is_between = (sort {$a <=> $b} $query_ref_galign_end - $kilobase, $query_ref_galign_end + $kilobase, $target_ref_galign_start )[1] == $target_ref_galign_start;
                if ($ref_is_between) {
                    my $nonref_is_between = (sort {$a <=> $b} $query_nonref_galign_end - $kilobase, $query_nonref_galign_end + $kilobase, $target_nonref_galign_start )[1] == $target_nonref_galign_start;
                    if ($nonref_is_between) {
                        push @merged, $t_gb;

                        $query_ref_galign_end = $tgalign_ref->[$ref_id]->dnafrag_end();
                        $query_nonref_galign_end =$tgalign_ref->[$non_ref_id]->dnafrag_end();
                        $remove_ref->{$t_gb} = 1;

                    }
                 }
            }

            my $length=0;
            #find the total length of the merged blocks
#            print "NOW going to get the total length of merged  ", scalar @merged, "\n\n\n";
            my $galigns;
            foreach my $gbk (@merged ) {

                $galigns = $whole_gblocks_hash_ref->{$gbk}->get_all_GenomicAligns();
#               print $galigns->[$ref_id]->length() , " JJJJJJj\n";
                $length += $galigns->[$ref_id]->length();

            }

            if ($length > $kilobase) { 

                my $start=2000000000000000000000; 
                my $end=0;
                my $chr;
                my $block_ids;
#           print $temp[0] ,"ggggggggggggg\n";
                foreach my $gbk (@merged) {

#               print $gbk , "kkkkkkkkkk\n";
                    $block_ids .= "\t" . $whole_gblocks_hash_ref->{$gbk}->dbID();
                    my $galigns = $whole_gblocks_hash_ref->{$gbk}->get_all_GenomicAligns();
                    $chr = $galigns->[$ref_id]->dnafrag()->name();
                    if ($start > $galigns->[$ref_id]->dnafrag_start()){
                        $start = $galigns->[$ref_id]->dnafrag_start();
                    }

                    if ($end < $galigns->[$ref_id]->dnafrag_end()){
                        $end = $galigns->[$ref_id]->dnafrag_end();
                    }
                }

                print OUT1 $chr, "\t\t",$length, "\t\t", $start ,"\t\t", $end, $block_ids,"\n\n";
                $no_of_col_blocks ++;
#                unshift @merged, $length;

#                $result_inner_hash_ref->{$key}{$counter}= \@merged; 
#                $counter ++;
#                print Dumper($result_inner_hash_ref);
            }
        }
    }
#    print Dumper($result_inner_hash_ref);
#    POSIX::_exit(0);
}

close(OUT1);
print STDOUT "Finito!!!! \n $no_of_col_blocks \n\n";
#print Dumper($result_inner_hash_ref);
POSIX::_exit(0);
