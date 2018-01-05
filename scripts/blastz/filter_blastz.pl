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



###############################################Rewrite for Bz output.

use strict;
use warnings;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlign;
#use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Compara::DnaFrag;
use Getopt::Long;

$|=1;

my $usage="
$0 [-help]
	-F 	filename		(Fr2.229.err)
	-O 	output file name 	(Fr2HS34_chr22 for gff line data)
	-D 	diff between aligns to be included as 1 (15000)
	-S1 	species 1 (Query)	(Fr)
	-S2 	species 2 (target)	(Hs)
	-ML	method_link		BLASTZ_ENSEMBL
	 (optional)
	 NB presumes that the dnafrags are already loaded
	";

my ($file, $outfile, $data ,$sps1 ,$sps2, $method_link, $diff,$matrix_file,$help);

my $minus_count=0;
my @new_features=();
my %prev;
my $i=0;
my @all=();
my @sorted=();
my $db;
my $no=0;
unless (scalar @ARGV) {print $usage; exit 0;}

GetOptions(	'help'		=>	\$help, 
		'F=s'		=>	\$file,
		'O=s'		=>	\$outfile, 
		'S1=s'		=>	\$sps1,
		'S2=s'		=>	\$sps2, 
		'D=i'		=>	\$diff,
		'ML=s' 		=>	\$method_link);
		
if ($help){print $usage; exit 0;}

my $t3stats=$outfile.".t3";
$data=$outfile.".data";

		my ($chr1, $seq_type1, $chr1_2, $offset1, $chr2,$seq_type2, $offset2);


	open (FILE, $file) or die  "can't open $file: $!";
print STDERR "opening $file\n";
	open (DATA, ">$data") or die "can't open $data: $!"; 
	
#	print OUT "track name=$track description=\"BLASTz of $sps1 with $sps2(GFF)\" useScore=1 color=333300\n";
	my $c=0;
	LINE:while (my $line=<FILE>)
		{
		$c++;
		chomp $line; 
		my @atrib=split /\t/,$line;
		
		unless ((defined($atrib[9])) && ($atrib[0] =~ /$sps1/) && ($atrib[2]-$atrib[1] >=15)){#print "$line\n";
		 next LINE;}
		if ($sps1 =~/Am/){
			($chr1, $chr1_2, $offset1) = split /\./,$atrib[0];#just for BEE
			$chr1=$chr1.".".$chr1_2;#just for BEE
			}
		else{
			$atrib[0] =~/$sps1\.(\S+):(\S+)\.(\d+)$/; #use for rest
			$seq_type1=$1;
		 	$chr1 = $2; 
			$offset1=$3;
			}
			
		$atrib[3] =~/$sps2\.(\S+):(\S+)\.(\d+)$/; #use for rest
			$seq_type2=$1;
		 	$chr2 = $2;
			$offset2=$3;
#print STDERR "$c $chr1\t$chr2\t\t";		
		
		$offset1--; $offset2--;
		my $Qstart=$offset1+$atrib[1];
		my $Qend=$offset1+$atrib[2];
		my $Hstart=$offset2+$atrib[4];
		my $Hend=$offset2+$atrib[5];
		
################################################################################################################
#####CREATE SCORE and IDENT and POSIT 
my $Qstrand_sign;

my $Qst=$atrib[6]; if ($Qst==-1){$Qstrand_sign= '-';} else {$Qstrand_sign='+';}
my $Hst= 1;

#print STDERR "Qst: $Qst\n";
#print STDERR "Hst: $Hst\n";
				 
my $score=$atrib[7]; my $id=$atrib[8];

##########################################
####Calc %id
#####################################

if ($score<=0){
		print STDERR " $score for $chr1, $Qstart, $Qend, $Qst, $chr2, $Hstart, $Hend, $Hst\n"; 
		$minus_count++;
		$score=0;
		next LINE;} 				 
				 
		
		$all[$i] = {	sps1	=> $sps1,
				chr1 	=> $chr1,
				seq_type1 => $seq_type1,
				Q_start => $Qstart,
				Q_end 	=> $Qend,
				sps2	=> $sps2,
				chr2 	=> $chr2,
				seq_type2 => $seq_type2,
				T_start	=> $Hstart,
				T_end 	=> $Hend,
				score 	=> $score,
				Q_strand	=> $Qst,
				T_strand	=> $Hst,
				Q_strand_s	=> $Qstrand_sign,
				T_strand_s	=> '+',
				ident	=> $id,
				cigar	=> $atrib[9]
				};
			#print STDERR " $sps1,$chr1, $Qstart, $Qend, $sps2, $chr2, $Hstart, $Hend, $score, $Qst, $Hst,$id,$atrib[9]\n";
				
		$i++;#should start at 0 
		
		}
	#need to sort array on Hstart first 
#NB I DO CHECK THAT THE Query ALIGNMENTS ARE ON DIFFERENT SCAFFOLDS -- NOT NEEDED FOR HS AS THEY ARE ALL ON ONE CHR!!!!!!!

#FIRST GROUP BY Query seq_region
my @sorteds=sort{$a->{chr1} cmp $b->{chr1} || $a->{Q_start} <=> $b->{Q_start}} @all;
my $prev_chr; my $chr=0; my @all_same;
my $lc=0;
@all=();

CHR:foreach my $ali (@sorteds){ 
	$lc++;
	$chr=$ali->{chr1};
	if (defined($prev_chr)){
		#print STDERR $ali->{chr1}." $chr $prev_chr line 90 ".$ali->{T_start}." ".$ali->{Q_start}."\n";
			
			
			
		#next chr or end of file
		if (($prev_chr ne $chr) || ($lc==scalar @sorteds)){	
		
		my @sorted_hsps=sort{$a->{T_start}<=>$b->{T_start} || $a->{Q_start} <=> $b->{Q_start}} @all_same;
				
my $A=0; my $qsdiff=0; my $qediff=0; my $ssdiff=0; my $sediff=0; my $compare;
my @parsed_hsps=@sorted_hsps;	
my @features;
	
OVERLAP:foreach my $align (@sorted_hsps){###Need to redo this as a sub

    	unless ($A==0){

    		if (($align->{T_start} <= $compare->{T_end}) && ((($align->{Q_start} <= $compare->{Q_end}) && ($align->{Q_start} >= $compare->{Q_start})) || (($align->{Q_start} <= $compare->{Q_start}) && ($align->{Q_end} >= $compare->{Q_start})))){
		
		#it overlaps -- on both q and s don't care if it only overlaps on one strand as may be repeat
#print STDERR "Overlap:$A \n";
			if (($align->{Q_strand} eq $compare->{Q_strand}) && ($align->{T_strand} eq $compare->{T_strand})){
#same strand - do they extend each other? keep both otherwise keep higher score
					
#calculate the diff at each end and see if this is greater than eg 2aa
				
				$qsdiff= $align->{Q_start} - $compare->{Q_start}; #should always be positive
				$qediff= $align->{Q_end} - $compare->{Q_end} ;#should be positive to be included 
						 
				$ssdiff= $align->{T_start} - $compare->{T_start}; 
				$sediff= $align->{T_end} - $compare->{T_end} ;#should be positive to be included 
				
				if($align->{score} >= $compare->{score}) {
					unless(($ssdiff > 6) || ($sediff < -6)){
						#ditch $compare
						my $sp=splice @parsed_hsps, $A-1, 1;
#print STDERR "a-1: ".$compare->{score} ." ditch i-1". $sp->{score}." \n";
						  $compare=$align; next OVERLAP;
						 }
					else{#keep both as extend
						#push @kept_hsps, $compare;
						$compare=$align; $A++; next OVERLAP;
						}
					}
					
				elsif($align->{score} < $compare->{score}) {
					unless ($sediff > 6){
						#ditch align
						my $sp=splice @parsed_hsps, $A, 1;
#print STDERR "$qediff align: ".$align->{score}." ditch align". $sp->{score}." \n";
						 next OVERLAP;
						}
					else{#keep both as extend
						#push @kept_hsps, $compare;
						$compare=$align; $A++; next OVERLAP;
						}
					}
				
#print STDERR "keep both same strand should never get here$A\n";				
					#push @kept_hsps, $compare;
					$compare=$align; $A++; next OVERLAP; 
				}
#######NB must remember to return only those hsps that pass this 
			else{#diff strand therfore just keep the one with the highest score 
			####unless overlap is very small ie due to possible palindromic regulatory region etc
			#calc overlap 
				if(($compare->{T_end}-$align->{T_start})<20){;
			
				if ($compare->{score} > $align->{score}) {
					#ditch align
					my $sp=splice @parsed_hsps, $A, 1;
#print STDERR "align: ".$align->{score}." (".$compare->{score} ." ) splice align ". $sp->{score}." \n";
					 next OVERLAP;
					}
				elsif ($compare->{score} < $align->{score}) {
					#ditch i-1
					my $sp=splice @parsed_hsps, $A-1, 1;
#print STDERR "a-1: ".$compare->{score} ." (".$align->{score}." ) splice i-1 ". $sp->{score}." \n";
					 $compare=$align; next OVERLAP;
					}
				else{#keep both
					#push @kept_hsps, $compare;
				$compare=$align; $A++; next OVERLAP; 
					}
				  }
				}
			}
		else{ 
#print STDERR "no overlap keep $A\n";		
					#push @kept_hsps, $compare;
			$compare=$align; $A++; next OVERLAP;#don't overlap --keep and use as next $align
			}
	    	}
	else{ 
		$compare=$align; 
#print STDERR "First pass a=$A;\n";
		$A++; #only used on first pass
		#do something????
		next OVERLAP;
		}
	}#end foreach/OVERLAP
	#print STDERR " end of overlap1 before push ". scalar(@features)."  ".scalar(@parsed_hsps)."\n";
	
   push (@features, @parsed_hsps);#	
#########################################
   #same again but sorted by the other species.
#########################################
#########################################
my @new_sorted_hsps=sort{$a->{Q_start}<=>$b->{Q_start} || $a->{T_start} <=> $b->{T_start}} @features;
				
 $A=0; $qsdiff=0; $qediff=0;  $ssdiff=0;  $sediff=0; $compare='';
my @new_parsed_hsps=@new_sorted_hsps;	


NEWOVERLAP:foreach my $align (@new_sorted_hsps){###Need to redo this as a sub

    	unless ($A==0){

    		if (($align->{Q_start} <= $compare->{Q_end}) && ((($align->{T_start} <= $compare->{T_end}) && ($align->{T_start} >= $compare->{T_start})) || (($align->{T_start} <= $compare->{T_start}) && ($align->{T_end} >= $compare->{T_start})))){
		
		#it overlaps -- on both q and s don't care if it only overlaps on one strand as may be repeat
#print STDERR "Overlap:$A \n";
			if (($align->{Q_strand} eq $compare->{Q_strand}) && ($align->{T_strand} eq $compare->{T_strand})){
				
				$qsdiff= $align->{Q_start} - $compare->{Q_start}; #should always be positive
				$qediff= $align->{Q_end} - $compare->{Q_end} ;#should be positive to be included 
						 
				$ssdiff= $align->{T_start} - $compare->{T_start}; 
				$sediff= $align->{T_end} - $compare->{T_end} ;#should be positive to be included 
				
				if($align->{score} >= $compare->{score}) {
					unless(($qsdiff > 6) || ($qediff < -6)){
						#ditch $compare
						my $sp=splice @new_parsed_hsps, $A-1, 1;
#print STDERR "a-1: ".$compare->{score} ." ditch i-1". $sp->{score}." \n";
						  $compare=$align; next NEWOVERLAP;
						 }
					else{#keep both as extend
						$compare=$align; $A++; next NEWOVERLAP;
						}
					}
					
				elsif($align->{score} < $compare->{score}) {
					unless ($qediff > 6){
						#ditch align
						my $sp=splice @new_parsed_hsps, $A, 1;
#print STDERR "$qediff align: ".$align->{score}." ditch align". $sp->{score}." \n";
						 next NEWOVERLAP;
						}
					else{#keep both as extend
						$compare=$align; $A++; next NEWOVERLAP;
						}
					}				
				$compare=$align; $A++; next NEWOVERLAP; 
				}
			else{#diff strand therfore just keep the one with the highest score####unless overlap is very small ie due to possible palindromic regulatory region etc
			#calc overlap 
				if(($compare->{T_end}-$align->{T_start})<20){;
				if ($compare->{score} > $align->{score}) {
					#ditch align
					my $sp=splice @new_parsed_hsps, $A, 1;
#print STDERR "align: ".$align->{score}." (".$compare->{score} ." ) splice align ". $sp->{score}." \n";
					 next NEWOVERLAP;
					}
				elsif ($compare->{score} < $align->{score}) {
					#ditch i-1
					my $sp=splice @new_parsed_hsps, $A-1, 1;
#print STDERR "a-1: ".$compare->{score} ." (".$align->{score}." ) splice i-1 ". $sp->{score}." \n";
					 $compare=$align; next NEWOVERLAP;
					}
				else{#keep both
#print STDERR "keep both as scores the same".$align->{score}.", ".$compare->{score}."\n";				
				$compare=$align; $A++; next NEWOVERLAP; 
					}
				  }
				}
			}
		else{ 
#print STDERR "not overlap $A\n";
			$compare=$align; $A++; next NEWOVERLAP;#don't overlap --keep and use as next $align
			}
	    	}
	else{ 
		$compare=$align; 
#print STDERR "First pass a=$A;\n";
		$A++; #only used on first pass
		#do something????
		next NEWOVERLAP;
		}
	
	}#end foreach/OVERLAP
	#print STDERR " end of overlap2 before push ". scalar(@new_features)."  ".scalar(@new_parsed_hsps)."\n";
   push (@new_features, @new_parsed_hsps);#	
 		@all_same=();
		#print STDERR $ali->{chr1}." $chr $prev_chr\n";
		push @all_same, $ali;
		$prev_chr=$chr;
 		next CHR;
			}
		elsif($prev_chr eq $chr){
			push @all_same, $ali;
			#print scalar(@all_same)." ". ref($ali)."\n";
			}

		}
	else {#first pass
	push @all_same, $ali;
		$prev_chr=$chr;
		}
	}

my @sorted_features;

print scalar(@new_features)." line left after overlap step\n\n";
###To display for query
###To display for target
	@sorted_features=sort{$a->{chr2} cmp $b->{chr2} || $a->{chr1} cmp $b->{chr1} ||$a->{T_start}<=>$b->{T_start}|| $a->{Q_start}<=>$b->{Q_start}} @new_features;


	my $x=0;my $ok=0; my @next; my @resorted; my $prev;  my $no_prev_groups=1; my $group=-1; my $y=1;
	
	
	while ($group != 0){
	
	$no_prev_groups=$x; $x=0; $ok=0; @next =(); $group =0;
#print STDERR "while loop $x $group $y sorted features: ".scalar(@sorted_features)."next: ". scalar(@next)."\n";
	
	FIRST:foreach my $array (@sorted_features){
	
#print STDERR "FIRST loop $x, $group, $y\t";
		
		 $x++;  $ok++; #start at 1 #x is just a counter now
		unless ($ok==1){
#		print STDERR $sorted_features[$ok-2]->{chr1}." eq ".$array->{chr1}."\n";
			
			if (($prev->{chr2} eq $array->{chr2}) && ($prev->{chr1} eq $array->{chr1})){ ##use when strand irrelevant for grouping 
			
			
				my $deltaH = $array->{T_start}-$prev->{T_end};
				my $deltaQ = $array->{Q_start}-$prev->{Q_end};
			$deltaH=~ s/-//; $deltaQ=~s/-//;
			
				if (($deltaH <= $diff) && ($deltaQ <= $diff)){#group
					$prev=$array;
					$array->{group} = $y;
					push @resorted, $array;
					$group++;
					}
				elsif ($deltaH>$diff){
					$y++;
					$array->{group} = $y;
					$prev=$array;
					push @resorted, $array;
					}
				else {
					push @next, $array;
					
					}
				}
			else {
				$y++;
				$array->{group} = $y;
				$prev=$array;
				push @resorted, $array;
				}
			}
		else {
			$array->{group} = $y;
			$prev =$array;
			push @resorted, $array;
			}
		}#end of first loop
		
		@sorted_features=@next;

	}
	foreach my $ungrouped (@next){	
		unless($ungrouped->{group}){
			$y++;
			$ungrouped->{group}=$y;######or could make the group = 0 for ungrouped?????
			}
		}
	#end of while
#print scalar(@resorted). "    ".scalar(@next)." $y\n";
	push @resorted, @next;	
print STDERR scalar(@resorted)."lines left \n";		
foreach my $array (@resorted) {	
if ($chr1 =~/Un/ ||$chr2=~/Un/) 
	#should be no group for these 
	{
	unless($array->{group}){
		$y++;
		$array->{group}="bob";
		
			}
		}

		print DATA "$no($array->{group})\t$array->{sps1}\t$array->{chr1}\t$method_link\tSIMILAR\t$array->{Q_start}\t$array->{Q_end}\t$array->{Q_strand}\t$array->{sps2}\t$array->{chr2}\t$array->{T_start}\t$array->{T_end}\t$array->{T_strand}\t$array->{score}\t$array->{ident}\t.\t$array->{cigar}\n";
		$no++;
		
}		
		
####use if strand needed		
		#unless ((defined($prev{T_strand})) && ($prev{T_strand} eq $array->{T_strand}) && ($prev{T_end}>$array->{T_end})){ $prev{T_end}=$array->{T_end};}
		#$prev{T_strand}=$array->{T_strand};
		
		print STDERR "Finished\nLost $minus_count bad seqs\n";		 
close FILE; #close OUT; 
close DATA;


