#!/usr/local/ensembl/bin/perl -w

# This script, originally written by Jim Mullikin, then called cigar.pl was remaned to FilterBlast.pl
# and addpated to also filter wutblastx outputs

use strict;
use Getopt::Long;

my $p = "blastn";

GetOptions('p=s' => \$p);

my $org = shift;
my $minscore = shift;
my $Q = "";
my $Schr = "";
my $Spos = "";
my $Sst = 0;
my $Sen = 0;
my $Qst = 0;
my $Qen = 0;
my $Qs = "";
my $Ss = "";
my $mc = 0;
my @mi;


while (<>) {
	chomp;
	last if (/^Parameters/);
	if (/^Query=  (\S+)/) {
		$Q = $1;
		next;
	}
	if (/^>$org(\S+)\.(\d+)/) {
		$Schr = $1;
		$Spos = $2;
		next;
	}
	if (/^ Score = (\d+)/) {
		if($Sst != 0) {
			$mi[$mc]{Schr} = $Schr;
			if ($Sst <= $Sen) {
			  $mi[$mc]{Sst} = $Spos+$Sst-1;
			  $mi[$mc]{Sen} = $Spos+$Sen-1;
			  $mi[$mc]{Sorient} = "+";
			} else {
			  $mi[$mc]{Sst} = $Spos+$Sen-1;
			  $mi[$mc]{Sen} = $Spos+$Sst-1;
			  $mi[$mc]{Sorient} = "-";
			}
			$mi[$mc]{Ss} = $Ss;
			$mi[$mc]{Qs} = $Qs;
			if($Qst <= $Qen) {
				$mi[$mc]{Qst} = $Qst;
				$mi[$mc]{Qen} = $Qen;
				$mi[$mc]{orient} = "+";
			} else {
				$mi[$mc]{Qst} = $Qen;
				$mi[$mc]{Qen} = $Qst;
				$mi[$mc]{orient} = "-";
			}
			$mc++;
		}
		$mi[$mc]{score} = $1;
		$Sst = 0;
		$Sen = 0;
		$Qst = 0;
		$Qen = 0;
		$Qs = "";
		$Ss = "";
		next;
	}
	if (/^ Identities = \S+\s+\((\d+)%\),\s+/) {
	  $mi[$mc]{identity} = $1;
	}
	if ($Qst == 0 and /^Query:\s*(\d+)/) {
		$Qst = $1;
	}
	if ($Sst == 0 and /^Sbjct:\s*(\d+)/) {
		$Sst = $1;
	}
	if (/^Query:\s+\d+\s+(\S+)\s+(\d+)$/) {
		$Qs .= $1;
		$Qen = $2;
		next;
	}
	if (/^Sbjct:\s+\d+\s+(\S+)\s+(\d+)$/) {
		$Ss .= $1;
		$Sen = $2;
		next;
	}
}
if($Sst != 0) {
	$mi[$mc]{Schr} = $Schr;
	if ($Sst <= $Sen) {
	  $mi[$mc]{Sst} = $Spos+$Sst-1;
	  $mi[$mc]{Sen} = $Spos+$Sen-1;
	  $mi[$mc]{Sorient} = "+";
	} else {
	  $mi[$mc]{Sst} = $Spos+$Sen-1;
	  $mi[$mc]{Sen} = $Spos+$Sst-1;
	  $mi[$mc]{Sorient} = "-";
	}
	if($Qst <= $Qen) {
		$mi[$mc]{Qst} = $Qst;
		$mi[$mc]{Qen} = $Qen;
		$mi[$mc]{orient} = "+";
	} else {
		$mi[$mc]{Qst} = $Qen;
		$mi[$mc]{Qen} = $Qst;
		$mi[$mc]{orient} = "-";
	}
}

my @rangesS = ();
my @rangesQ = ();
my %vote = ();
foreach (sort { $$b{score} <=> $$a{score} } @mi) {
	my %r = %{$_};
	next if $r{score} < $minscore;
	my $cm = int(($r{Sst}+$r{Sen})/2);
	my $covered = 0;
	foreach (@rangesS) {
		my @n = @{$_}; 
		if($cm > $n[0] and $cm < $n[1]) {
			$covered = 1;
			last;
		}
	}
	next if $covered;
	$cm = int(($r{Qst}+$r{Qen})/2);
	foreach (@rangesQ) {
		my @n = @{$_}; 
		if($cm > $n[0] and $cm < $n[1]) {
			$covered = 1;
			last;
		}
	}
	next if $covered;
	$vote{$r{Schr}.$r{orient}} += $r{score};
	my @q = ($r{Qst},$r{Qen});
	push @rangesQ,\@q;
	my @s = ($r{Sst},$r{Sen});
	push @rangesS,\@s;
}
@rangesS = ();
@rangesQ = ();
my $winC = "0";
foreach (keys %vote) {
	if($winC eq "0" or $vote{$winC} < $vote{$_}) {
		$winC = $_;
	}
}
my @mi2 = ();
my $w = 0.0;
my $wt = 0.0;
my @median = ();
foreach (sort { $$b{score} <=> $$a{score} } @mi) {
	my %r = %{$_};
	next if $r{Schr}.$r{orient} ne $winC;
	next if $r{score} < $minscore;
	my $covered = 0;
	my $cm = int(($r{Qst}+$r{Qen})/2);
	foreach (@rangesQ) {
		my @n = @{$_}; 
		if($cm > $n[0] and $cm < $n[1]) {
			$covered = 1;
			last;
		}
	}
	next if $covered;
	$cm = int(($r{Sst}+$r{Sen})/2);
	foreach (@rangesS) {
		my @n = @{$_}; 
		if($cm > $n[0] and $cm < $n[1]) {
			$covered = 1;
			last;
		}
	}
	next if $covered;
	push @median,$cm;
	my @q = ($r{Qst},$r{Qen});
	push @rangesQ,\@q;
	my @s = ($r{Sst},$r{Sen});
	push @rangesS,\@s;
}
@rangesS = ();
@rangesQ = ();
exit(0) if @median == 0;
@median = (sort {$a <=> $b} @median);
my $len = @median;
my $median = $median[int($len/2)];
my $min = $median - 300000;
my $max = $median + 300000;
foreach (sort { $$b{score} <=> $$a{score} } @mi) {
	my %r = %{$_};
	next if $r{Schr}.$r{orient} ne $winC;
	next if $r{score} < $minscore;
	my $cm = int(($r{Sst}+$r{Sen})/2);
	next if $cm < $min or $cm > $max;
	my $covered = 0;
	foreach (@rangesS) {
		my @n = @{$_}; 
		if($cm > $n[0] and $cm < $n[1]) {
			$covered = 1;
			last;
		}
	}
	next if $covered;
	$cm = int(($r{Qst}+$r{Qen})/2);
	foreach (@rangesQ) {
		my @n = @{$_}; 
		if($cm > $n[0] and $cm < $n[1]) {
			$covered = 1;
			last;
		}
	}
	next if $covered;
	my @q = ($r{Qst},$r{Qen});
	push @rangesQ,\@q;
	my @s = ($r{Sst},$r{Sen});
	push @rangesS,\@s;
	push @mi2,$_;
	$wt += ($r{Sst}+$r{Sen})/2*$r{score};
	$w += $r{score};
}
my $mean = $wt/$w;
my $stdev = 0.0;
foreach (@mi2) {
	my %r = %{$_};
	$stdev += ((($r{Sst}+$r{Sen})/2 - $mean)**2.0) * $r{score};
	#printf "%f %d $stdev\n",(($r{Sst}+$r{Sen})/2 - $mean),$r{score};
}
$stdev = (($stdev/$w)**0.5);
$min = $mean - 3.0*$stdev;
$max = $mean + 3.0*$stdev;
#printf "cm = %d %f\n",$mean,$stdev;
@mi2 = (sort { $$a{Sst} <=> $$b{Sst} } @mi2);
$len = @mi2;
my $start = 0;
my $actLen = 0;
for(my $i=0;$i<$len-1;$i++) {
	my %r = %{$mi2[$i]};
	my %s = %{$mi2[$start]};
	my %n = %{$mi2[$i + 1]};
	$actLen += $r{Sen} - $r{Sst};
	my $nextGap = $n{Sst} - $r{Sen};
	#print "$actLen $nextGap\n";
	my $m = ($r{Sst}+$r{Sen})/2;
	if($m < $min or ($actLen < 3000 and $actLen < $nextGap/10)) {
		$actLen = 0;
		$start = $i+1;
		next;
	}
}
my $end = $len-1;
$actLen = 0;
for(my $i=$len;--$i>=1+$start;) {
	my %r = %{$mi2[$i]};
	my %e = %{$mi2[$end]};
	my %p = %{$mi2[$i - 1]};
	$actLen += $r{Sen} - $r{Sst};
	my $nextGap = $r{Sst} - $p{Sen};
	#print "$actLen $nextGap\n";
	my $m = ($r{Sst}+$r{Sen})/2;
	if($m > $max or ($actLen < 3000 and $actLen < $nextGap/10)) {
		$actLen = 0;
		$end = $i-1;
		next;
	}
}
	
#foreach (sort { $$a{Sst} <=> $$b{Sst} } @mi2) {
#	my %r = %{$_};

for(my $i=$start;$i<=$end;$i++) {
	my %r = %{$mi2[$i]};
	next if(!exists($r{orient}) or !defined($r{orient}));
	my $cigar = cigar_gen($r{Qs},$r{Ss});

	if ($r{Sorient} eq "-") {
	 	  
	  # reverse strand in both sequences
	  $r{Sorient} = "+";
	  if ($r{orient} eq "+") {
	    $r{orient} = "-"
	  } elsif ($r{orient} eq "-") {
	    $r{orient} = "+"
	  }
	  
	  # reverse cigar_string as consequence
	  $cigar =~ s/(D|I|M)/$1 /g;
	  my @cigar_pieces = split / /,$cigar;
	  $cigar = "";
	  while (my $piece = pop @cigar_pieces) {
	    $cigar .= $piece;
	  }
	}

	printf "Similarity\t$Q:$r{Qst}-$r{Qen}\tPhusionBlast\thomology\t$r{Schr}\t$r{Sst}\t$r{Sen}\t$r{orient}\t.\t$r{score}\t$r{identity}\t".$cigar."\n";
}

sub cigar_gen {
	my ($q,$s) = @_;
	my @q = split //,$q;
	my @s = split //,$s;
	my $i = 0;
	my @ret = ();
	for(;$i<@q;$i++) {
		my $q = $q[$i];
		my $s = $s[$i];
		if($q eq "\-") {
			push @ret,"D";
			push @ret,("D","D") if ($p eq "tblastx");
			next;
		}
		if($s eq "\-") {
			push @ret,"I";
			push @ret,("I","I") if ($p eq "tblastx");
			next;
		}
		push @ret,"M";
		push @ret,("M","M") if ($p eq "tblastx");
	}
	#print "@ret\n";
	my $c = 0;
	my $ret = "";
	for($i=1;$i<@ret;$i++) {
		if($ret[$i] eq $ret[$i-1]) {
			$c++;
			next;
		}
		if($c == 0) {
			$ret .= $ret[$i-1];
			next;
		}
		$ret .= sprintf "%d$ret[$i-1]",++$c;
		$c = 0;
	}
	if($c == 0) {
		$ret .= $ret[$i-1];
	} else {
		$ret .= sprintf "%d$ret[$i-1]",++$c;
	}
	return $ret;
}
