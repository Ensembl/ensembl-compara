#!/usr/local/ensembl/bin/perl -w

# This script, originally written by Jim Mullikin, then called rmRedunGComp.pl was remaned to RemoveNonSyntenic.pl
# with no code modification


#Needs a couple of modifications: 1) does not include the first and last 3 of a chromosome
#which dosn't mean much for mouse/human but for unfinished genomes such as Fugu and Danio this will be a problem
#2) if there is a 'mismatch' to another chromosome within half the threshold difference of a breakpoint then the end of the first region of synteny will be lost.
#3)based on chromosome rather than chromosome and position. Rather than rewriting more, we decided that as hopefully will only need to run once, for 'complete' removal of nosyntenic regions, then a second run with the species reversed(ie other acts as reference) will throw out any occastions where rndm hits to the same chromosome have been included.
$| =1;
use strict;

my $thresh = shift;
my %simlines = ();
while(<>) {
	my ($d1,$comp,$d2,$d3,$Schr,$Sst,$Sen,$orient,$d4,$score) = split;
	my $avepos = ($Sst+$Sen)/2;
	if(defined($simlines{$Schr}{$avepos})) {
		my @f = split /\t/,$simlines{$Schr}{$avepos};
		next if($f[9] >= $score);#for a particular Subject(ref)chr and position, only uses the top scoring HSP
	}
	$simlines{$Schr}{$avepos} = $_;
}
my $mid = $thresh/2;
foreach my $Schr (sort keys %simlines) {#for each ref chr
	my @Q_chr_names = ();
	my @Q_chr_namelines = ();
	
#foreach chr need the first and last three (if thresh==6) 
	my $count=0;
	my %vote=();
	foreach my $pos (sort {$a <=> $b} keys %{$simlines{$Schr}}) { # take hsps in order along ref chr
		my $shift=0;
		my @f = split /\t/,$simlines{$Schr}{$pos};
		my $Qn = $f[1];	#query_chr_name
		$Qn =~ s/\:\d+\-\d+//; #removes the co-ordinate info
		THRESH: if (@Q_chr_names > $thresh) { #eg if there are 7 Q chr names
			$shift=0;
			%vote = ();
			foreach (@Q_chr_names) {
				$vote{$_}++;
			}
#			my @list = (keys %vote);
#			my $max = pop @list;
#			foreach (@list) {
#				$max = $_ if($vote{$max} < $vote{$_});
#			}
#		print "count: $count\t".scalar(@Q_chr_names)."\n";
			if ($count==@Q_chr_names){
				foreach my $i (0..$mid-1){
					if ($Q_chr_names[$i] eq $Q_chr_names[$mid]) {
						print "$Q_chr_namelines[$i]";
						}
					}
				}
				
			
			if($mid+1 <= $vote{$Q_chr_names[$mid]}) {
				print "$Q_chr_namelines[$mid]";
				}
			else{ 	splice (@Q_chr_names, $mid, 1);
				splice (@Q_chr_namelines, $mid, 1);
#				print "***$mid, $Q_chr_namelines[$mid],else/next\n";
				$shift=1;#don't shift
				}
			unless($shift){
				shift @Q_chr_names;
				shift @Q_chr_namelines;
				}
			}
		push @Q_chr_names,$Qn;
		push @Q_chr_namelines,$simlines{$Schr}{$pos};
		$count++;
	}
#	print "last ones $thresh, $count, ".scalar(@Q_chr_names)."\n";	
	foreach  my $i (1..$mid){
		if ($Q_chr_names[$mid+$i] eq $Q_chr_names[$mid]) {
			print  $Q_chr_namelines[$mid+$i];
			}
		}
		
	
}
