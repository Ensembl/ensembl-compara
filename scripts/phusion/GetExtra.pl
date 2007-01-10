#!/usr/local/ensembl/bin/perl -w

# This script, originally written by Jim Mullikin, then called PhusionBlastExtra.pl was renamed to GetExtra.pl
# with no code modification

use strict;

my $org = shift;
my $expandSecond = shift;
my @Mainlist;
my @Secondlist;
my $Mainlc = 0;
my $Secondlc = 0;
my %Mainplace;
my %Secondplace;
while ($ARGV[0] =~ /tag$/) {
	open F,shift;
	while(<F>) {
		my @f = split;
		if($f[0] =~ /$org/) {
			push @Mainlist,$f[0];
			$Mainplace{$f[0]} = $Mainlc;
			$Mainlc++;
		} else {
			push @Secondlist,$f[0];
			$Secondplace{$f[0]} = $Secondlc;
			$Secondlc++;
		}
	}
}

my %groupContigsMain = ();
my %groupContigsSecond = ();
my %contigGroupMain = ();
my %contigGroupSecond = ();

while(<>) {
	if(/readnames for contig\s+(\d+)\s+(\S+)\s+(\d+)/) {
		my $id = $1;
		my $name = $2;
		my $c = $3;
#		print "readnames for contig $id $name $c\n";
		while(--$c>=0) {
			my $line = <>;
			my @f = split / /,$line;
#			print "$f[1]\n";
			if($f[1] =~ /^$org/) {
				push @{$groupContigsMain{$name}},$f[1];
				$contigGroupMain{$f[1]} = $name;
			} else {
				push @{$groupContigsSecond{$name}},$f[1];
				$contigGroupSecond{$f[1]} = $name;
			}
		}
	}
}

foreach my $group (keys %groupContigsMain) {
	my @s = @{$groupContigsMain{$group}} = sort {$Mainplace{$a} <=> $Mainplace{$b}} @{$groupContigsMain{$group}};
	my $i = @s;
	my @ns = ();
	my $current = $Mainplace{$s[--$i]};
	unshift @ns,$Mainlist[$current+1] if $current+1 < $Mainlc;
	while($i>=0) {
		$current = $Mainplace{$s[$i]};
		unshift @ns,$Mainlist[$current];
		last if $i == 0;
		my $diff = $current - $Mainplace{$s[$i-1]};
		#printf "$s[$i] - $s[$i-1] = %d\n",$diff;
		if($diff > 1) {
			unshift @ns,$Mainlist[--$current];
			$diff -= 2;
			if($diff > 0) {
				$current -= $diff;
				unshift @ns,$Mainlist[$current];
			}
		}
		$i--;
	}
	$current--;
	unshift @ns,$Mainlist[$current] if $current >= 0;
	#print "\n";
	$i = @ns;
	while(--$i>0) {
		$current = $Mainplace{$ns[$i]};
		my $diff = $current - $Mainplace{$ns[$i-1]};
		#printf "$ns[$i] - $ns[$i-1] = %d\n",$diff;
	}
	#printf "$ns[$i]\n" if $i == 0;
	#print "\n";
	@{$groupContigsMain{$group}} = @ns;

	@s = @{$groupContigsSecond{$group}} = sort {$Secondplace{$a} <=> $Secondplace{$b}} @{$groupContigsSecond{$group}};
	$i = @s;
	@ns = ();
	if($expandSecond) {
		my $current = $Secondplace{$s[--$i]};
		if ($current+1 < $Secondlc and !exists($contigGroupSecond{$Secondlist[$current+1]})) {
			unshift @ns,$Secondlist[$current+1];
			$contigGroupSecond{$Secondlist[$current+1]} = $group;
		}
		#printf "$s[$i]\n" if $i == 0;
		while($i>=0) {
			$current = $Secondplace{$s[$i]};
			unshift @ns,$Secondlist[$current];
			last if $i == 0;
			my $diff = $current - $Secondplace{$s[$i-1]};
			#printf "$s[$i] - $s[$i-1] = %d\n",$diff;
			if($diff > 1) {
				--$current;
				if(!exists($contigGroupSecond{$Secondlist[$current]})) {
					unshift @ns,$Secondlist[$current];
					$contigGroupSecond{$Secondlist[$current]} = $group;
				}
				$diff -= 2;
				if($diff > 0) {
					$current -= $diff;
					if(!exists($contigGroupSecond{$Secondlist[$current]})) {
						unshift @ns,$Secondlist[$current];
						$contigGroupSecond{$Secondlist[$current]} = $group;
					}
				}
			}
			$i--;
		}
		$current--;
		if($current >= 0 and !exists($contigGroupSecond{$Secondlist[$current]})) {
			unshift @ns,$Secondlist[$current] if $current >= 0;
			$contigGroupSecond{$Secondlist[$current]} = $group;
		}
		#print "\n";
	} else {
		@ns = @s;
	}
	$i = @ns;
	while(--$i>0) {
		$current = $Secondplace{$ns[$i]};
		my $diff = $current - $Secondplace{$ns[$i-1]};
		#printf "$ns[$i] - $ns[$i-1] = %d\n",$diff;
	}
	#printf "$ns[$i]\n" if $i == 0;
	#print "\n";
	@{$groupContigsSecond{$group}} = @ns;
}

my $id = 0;
foreach my $group (keys %groupContigsMain) {
	my @s = @{$groupContigsMain{$group}} = sort {$Mainplace{$a} <=> $Mainplace{$b}} @{$groupContigsMain{$group}};
	my @s2 = @{$groupContigsSecond{$group}} = sort {$Secondplace{$a} <=> $Secondplace{$b}} @{$groupContigsSecond{$group}};
	$id++;
	my $c = @s + @s2;;
	print "readnames for contig $id $group $c\n";
	foreach (@s,@s2) {
		print "$_\n";
	}
}
