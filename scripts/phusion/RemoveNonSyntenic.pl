#!/usr/local/ensembl/bin/perl -w

# This script, originally written by Jim Mullikin, then called rmRedunGComp.pl was remaned to RemoveNonSyntenic.pl
# with no code modification

use strict;

my $thresh = shift;
my %simlines = ();
while(<>) {
	my ($d1,$comp,$d2,$d3,$Schr,$Sst,$Sen,$orient,$d4,$score) = split;
	my $avepos = ($Sst+$Sen)/2;
	if(exists($simlines{$Schr}{$avepos})) {
		my @f = split /\t/,$simlines{$Schr}{$avepos};
		next if($f[9] >= $score);
	}
	$simlines{$Schr}{$avepos} = $_;
}
my $mid = $thresh/2;
foreach my $Schr (sort keys %simlines) {
	my @fifo = ();
	my @fifol = ();
	foreach my $pos (sort {$a <=> $b} keys %{$simlines{$Schr}}) {
		my @f = split /\t/,$simlines{$Schr}{$pos};
		my $Qn = $f[1];
		$Qn =~ s/\:\d+\-\d+//;
		if(@fifo > $thresh) {
			my %vote = ();
			foreach (@fifo) {
				$vote{$_}++;
			}
#			my @list = (keys %vote);
#			my $max = pop @list;
#			foreach (@list) {
#				$max = $_ if($vote{$max} < $vote{$_});
#			}
			if($mid+1 <= $vote{$fifo[$mid]}) {
				print $fifol[$mid];
			}
			shift @fifo;
			shift @fifol;
		}
		push @fifo,$Qn;
		push @fifol,$simlines{$Schr}{$pos};
	}
}
