#!/usr/local/ensembl/bin/perl -w

# This script, originally written by Jim Mullikin, then called rmRedunGComp.pl was remaned to RemoveNonSyntenic.pl
# with no code modification


#if the thresh is >=6 it uses chromosome subdivisions else just takes whole chrs 
###should something be added to check that 'syntenous' regions are actually next 
#to each other on the chr and not at either end of the same chr


$| =1;
use strict;
my $shift=0;
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
	my %print =(); #to count the number of times each chr has been printed
#foreach chr need the first and last three (if thresh==6) 
	my $count=0;
	my %vote=();
	foreach my $pos (sort {$a <=> $b} keys %{$simlines{$Schr}}) { # take hsps in order along ref chr
#		 $shift=0;
		my @f = split /\t/,$simlines{$Schr}{$pos};
		my $Qn = $f[1];
		if ($thresh>=6){	#query_chr_name
			$Qn =~ s/\:\d+\-\d+//; #removes the co-ordinate info
			}
		else {$Qn =~ s/\.\S+\:\d+\-\d+//;} #removes the co-ordinate info and chr subdivision
		push @Q_chr_names,$Qn;
		push @Q_chr_namelines,$simlines{$Schr}{$pos};
		$count++;
		THRESH: if (@Q_chr_names > $thresh) { #eg if there are 7 Q chr names
			%vote = ();
			foreach (@Q_chr_names) {
				$vote{$_}++;
				}
				
			
			if ($count==@Q_chr_names){#concerned this will print out same things twice
				foreach my $i (0..$mid-1){
					if ($mid+1<= $vote{$Q_chr_names[$i]}) {
						print "$Q_chr_namelines[$i]";
						$print{$Q_chr_names[$i]}++;#print chr
						}
					}
				}
				
			if($mid+1 <= $vote{$Q_chr_names[$mid]}) {
				#before we print the 'mid' one check the previous
				my $mid_chr_no=0;
				for my $i (0..$mid-1){
					if ($Q_chr_names[$i] eq $Q_chr_names[$mid]){
						$mid_chr_no++;
						}
					}
				unless(defined($print{$Q_chr_names[$mid]})){
					#then print out missed ones
					for my $i (0..$mid-1){
						if ($Q_chr_names[$i] eq $Q_chr_names[$mid]){
							print "$Q_chr_namelines[$i]";
							$print{$Q_chr_names[$i]}++;#print chr
							}
						}
					
					}
				else {
					}
				print "$Q_chr_namelines[$mid]";
				$print{$Q_chr_names[$mid]}++;#print chr
				
				$shift=0;
				}
			else{ 	splice (@Q_chr_names, $mid, 1);
				splice (@Q_chr_namelines, $mid, 1);
				$shift=1;#don't shift
#				print "***$mid, $Q_chr_namelines[$mid],else/next\n";
				}
			unless($shift){
				if ($print{$Q_chr_names[0]}){
		#at the start of a chr it will not have been spliced outbut also won't have been printed
					$print{$Q_chr_names[0]}--;
					}
				shift @Q_chr_names;
				shift @Q_chr_namelines;
				}
			}
#		print "$shift, $count\n";
	}
#	print "last ones Shift: $shift\t$thresh, $count, ".scalar(@Q_chr_names)."\n";	
if (($count > $thresh) && (scalar(@Q_chr_names) >= $thresh)){

		foreach  my $i ($mid..$#Q_chr_names){
#		print STDERR " i:$i, mid: $mid..".$#Q_chr_names ."\n";
			if ($mid+1<= $vote{$Q_chr_names[$i]}) {
				print  $Q_chr_namelines[$i];
				}
			}
		}
	else {print STDERR " $count: (".scalar(@Q_chr_names).") $Schr not enough hits\n";} 
		#could put a loop in here but probably best to reduce the thresh number.
	
}
