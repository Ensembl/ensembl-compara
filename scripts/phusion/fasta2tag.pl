#!/usr/local/ensembl/bin/perl -w

# This script, originally written by Jim Mullikin, then called tagFA.pl was remaned to fasta2tag.pl
# with no code modification

use strict;

my ($i, $rp, $count, $name, $oname
	);
 
$name = "";
$oname = "";
my (%seq) = ();
my ($mindiff) = 0;
foreach $name (@ARGV) {
	if($name =~ /(\S+)\.gz$/ or $name =~ /(\S+)\.Z$/) {
		open F,"gunzip -c $name |";
		$name = $1;
	} else {
		open F,$name;
	}
	my ($tag) = "";
	my ($tail) = "";
	my ($length) = 0;
	my ($pos) = -1;
	my ($tellF) = 0.;
	while (<F>) {
		$tellF += length($_);
		chomp;
		my ($line) = $_;
		if ($line =~ /^\>(\S+)\s*(.*)/) {
			if($pos >= 0) {
				printf "%s %.0f $length $name %s\n",$tag,$pos,$tail;
				$length = 0;
			}
			$tag = $1;
			$tail = "";
			$tail = $2 if defined $2;
			$pos = $tellF - length($line) - 1;
			next;
		}
		if ($line =~ /^[acgtACGTnN]/) {
			$length += length($line);
			next;
		}
	}
	close F;
	printf "%s %.0f $length $name %s\n",$tag,$pos,$tail;
}
