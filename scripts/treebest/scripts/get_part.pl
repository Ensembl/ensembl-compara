#!/usr/bin/perl -w

die("Usage: get_part.pl <name> [<njtree_output>]\n") if (@ARGV == 0);
$name = shift(@ARGV);

$flag = 0;
while (<>) {
	if (/^\@begin (\S+)/) {
		$flag = ($1 eq $name)? 1 : 0;
	} elsif (/^\@end/) {
		$flag = 0;
	} elsif ($flag) {
		print;
	}
}
