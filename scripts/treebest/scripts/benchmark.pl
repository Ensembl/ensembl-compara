#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;
use File::Copy qw(cp);

my %opt = (t=>100, d=>-1.0, l=>-1.0, p=>-1.0, a=>-1.0, m=>'WAG', b=>'jtt', n=>'njtree', s=>'seq-gen');
GetOptions(\%opt, "t=i", "d=f", "l=f", "p=f", "a=f", "i=f", "m=s", "b=s", "h!", "g=i", "n=s", "s=s");
if ($opt{h}) {
	&usage(\%opt);
	exit 1;
}

my $p = "tmp";

for (my $i = 0; $i < $opt{t}; ++$i) {
	my $height = 0.25 * rand() + 0.25;
	my $len = int(850 * rand() + 150);
	my $d = ($opt{d} < 0.0)? 0.20 * rand() : $opt{d};
	my $l = ($opt{l} < 0.0)? 0.02 * rand() : $opt{l};
	my $P = ($opt{p} < 0.0)? 0.30 * rand() : $opt{p};
	my $a = ($opt{a} < 0.0)? exp(2.0 * rand() - 1.0) : $opt{a};
	system("$opt{n} simulate -p $P -d $d -l $l -nm $height > simu-$p.nh");
	my ($fh, $fh_out);
	open($fh_out, ">simu-$p.mfa");
	open($fh, "$opt{s} -or -m$opt{m} -a $a simu-$p.nh 2>/dev/null |");
	<$fh>;
	while (<$fh>) {
		if (/^(\S+)\s+(\S+)$/) {
			print $fh_out ">$1\n$2\n";
		}
	}
	close($fh);
	close($fh_out);
	system("$opt{n} nj -t $opt{b} -b0 simu-$p.mfa > simu-$p.nhx");
	system("cat simu-$p.nh simu-$p.nhx | $opt{n} merge - > /dev/null 2>simu-$p.count");
	open($fh, "simu-$p.count");
	if (<$fh> =~ /^(\d+)\s(\d+)\s(\d+)\s(\d+)$/) {
		printf "%d\t%.3f\t%.3f\t%.3f\t%.3f\t", $i, $d, $l, $P, $a;
		print "$1\t$2\t$3\t$4\n";
		$| = 1;
		if ($4 > 0) {
			cp("simu-$p.nhx", "simu.$i.nhx");
			cp("simu-$p.nh",  "simu.$i.nh");
		}
	}
	close($fh);
}

sub usage
{
	my $opt = shift;
	print <<EOF;

Usage:   benchmark.pl [options]

Options: -t INT         number of iterations [$opt->{t}]
         -d FLOAT       duplication probability [$opt->{d}]
         -l FLOAT       loss probability [$opt->{l}]
         -p FLOAT       loss probability directly after duplication [$opt->{p}]
         -a FLOAT       shape parameter (alpha) for gamma distribution [$opt->{a}]
         -m STR         model of generator [$opt->{m}]
         -b STR         model of tree builder [$opt->{b}]
         -n STR         path of njtree [$opt->{n}]
         -s STR         path of seq-gen [$opt->{s}]
         -h             help

EOF
}
