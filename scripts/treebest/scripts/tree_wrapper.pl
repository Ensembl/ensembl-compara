#!/usr/local/bin/perl -w

use strict;
use Cwd qw/getcwd/;
use Getopt::Long;

my $usage = '
Program: tree_wrapper.pl
Version: 0.2.1, on 07 August 2006
Contact: Heng Li <lh3@sanger.ac.uk>

Command: dnapars    DNA parsimoneous tree (PHYLIP, dnapars)
         protpars   amino acids parsimoneous tree (PHYLIP, protpars)
         distmat    distance matrix (TREE-PUZZLE, puzzle)
         fastme     fastME tree (FASTME, fastme)
         fitch      Fitch-Margoliash method (PHYLIP, fitch)

';

die($usage) unless(@ARGV);
my $prog = shift(@ARGV);
my ($rst, $log) = ('', '');
if ($prog eq 'dnapars' || $prog eq 'protpars') {
	die("Usage: tree_wrapper.pl $prog <fasta_alignment>\n") unless(@ARGV);
	($rst, $log) = &run_pars($ARGV[0], $prog);
} elsif ($prog eq 'distmat') {
	my %opt;
	$usage = '
Usage  : tree_wrapper.pl distmat [options] <fasta_alignment>

Options: -c NUM     number of Gamma categrories (=1 or >=4) [1]
         -k FNUM|e  ts/tv ("e" for estimating) [e]
         -a FNUM|e  alpha parameter of Gamma distribution [1.0]

';
	die($usage) unless(@ARGV);
	GetOptions(\%opt, "c=i", "k=s", "a=s");
	($rst, $log) = &run_distmat($ARGV[0], \%opt);
} elsif ($prog eq 'fastme') {
	die("Usage: tree_wrapper.pl $prog <distmat>\n") unless(@ARGV);
	($rst, $log) = &run_fastme($ARGV[0]);
} elsif ($prog eq 'fitch') {
	die("Usage: tree_wrapper.pl $prog <distmat> [<tree>]\n") unless(@ARGV);
	($rst, $log) = &run_fitch($ARGV[0], $ARGV[1]);
}
print $rst;
print STDERR $log;

sub run_fastme
{
	my ($file) = @_;
	my $distmat = read_file($file);
	my $prog = gwhich("fastme");
	$prog || die("[run_fastme] fail to execute '$prog'");
	my $tmp_pre = "/tmp/fastme-$$-".time;
	my $fh;
	open($fh, ">$tmp_pre.in");
	print $fh $distmat;
	close($fh);
	system("$prog -i $tmp_pre.in -o $tmp_pre.out");
	my $rst = read_file("$tmp_pre.out");
	unlink("$tmp_pre.in", "$tmp_pre.out");
	return ($rst, '');
}
sub run_distmat
{
	my ($file, $opt) = @_;
	my $prog = 'puzzle';
	$prog = gwhich($prog);
	$prog || die("[run_pars] fail to find executable: $prog");
	my $n_cat = ($opt->{c} ||= 1);
	my $tstv = ($opt->{k} ||= 'e');
	my $alpha = ($opt->{a} ||= '1.0');
	$n_cat = 4 if ($n_cat != 1 && $n_cat < 4);
	my $tmp_pre = "/tmp/dist-$$-".time;
	my @array = &mfa2phy($file, $tmp_pre, 0);
	my $fh;
	my $is_2 = 1;
	# test puzzle
	open($fh, "echo q | $prog $tmp_pre 2>/dev/null |") || die("[run_distmat] fail to test $prog");
	while (<$fh>) {
		if (/Tree search procedure.*Quartet puzzling/) {
			$is_2 = 0;
			last;
		}
	}
	close($fh);
	warn("[run_distmat] large alignment? (just a warning)\n") if ($is_2);
	# do puzzle
	open($fh, "| $prog $tmp_pre >/dev/null 2>&1") || die("[run_distmat] fail to run $prog");
	print $fh ($is_2)? "k\nk\n" : "k\nk\nk\n";
	print $fh "t\n$tstv\n" if ($tstv ne 'e');
	print $fh "w\nc\n$n_cat\n" if ($n_cat != 1);
	print $fh "a\n$alpha\n" if ($n_cat > 1 && $alpha ne 'e');
	print $fh "y\n";
	close($fh);
	my $rst = read_file("$tmp_pre.dist");
	my $log = read_file("$tmp_pre.puzzle");
	unlink($tmp_pre, "$tmp_pre.dist", "$tmp_pre.puzzle");
	$rst =~ s/pZQa(\d{5})/$array[$1]/g;
	$log =~ s/pZQa(\d{5})/$array[$1]/g;
	return ($rst, $log);
}
sub run_pars
{
	my ($file, $prog) = @_;
	$prog = gwhich($prog);
	$prog || die("[run_pars] fail to find PHYLIP executables: $prog");
	my $cwd = getcwd;
	my $tmp_dir = "/tmp/pars-$$-".time;
	mkdir($tmp_dir);
	my @array = &mfa2phy("$file", "$tmp_dir/infile");
	chdir($tmp_dir);
	my $fh;
	open($fh, "| $prog >/dev/null 2>&1") || die("[run_pars] fail to run $prog");
	print $fh "y\n";
	close($fh);
	my $rst = read_file("outtree");
	my $log = read_file("outfile");
	unlink("infile", "outfile", "outtree");
	chdir($cwd);
	rmdir($tmp_dir);
	$rst =~ s/pZQa(\d{5})/$array[$1]/g;
	$log =~ s/pZQa(\d{5})/$array[$1]/g;
	return ($rst, $log);
}
sub run_fitch
{
	my ($file, $tree_file) = @_;
	$prog = gwhich('fitch');
	$prog || die("[run_fitch] fail to find PHYLIP executables: fitch");
	my $cwd = getcwd;
	my $tmp_dir = "/tmp/fitch-$$-".time;

	my ($fh, $fhw, @array, %hash);
	mkdir($tmp_dir);
	open($fh, $file) || die("[run_fitch] fail to open $file");
	open($fhw, ">$tmp_dir/infile");
	$_ = <$fh>; print $fhw $_;
	while (<$fh>) {
		if (/^(\S+)/) {
			my $digit = sprintf("pZQa%.5d", scalar(@array));
			$hash{$1} = $digit;
			push(@array, $1);
			s/^(\S+)/$digit/;
		}
		print $fhw $_;
	}
	close($fhw);
	close($fh);
	if ($tree_file) {
		$_ = read_file($tree_file);
		s/\s//g;
		s/\[[^\[\]]*\]//g;
		s/(\(|,)([^\s,:\(\)]+)(,|:|\))/$1$hash{$2}$3/g;
		write_file("$tmp_dir/intree", $_);
	}

	chdir($tmp_dir);
	open($fh, "| $prog >/dev/null 2>&1") || die("[run_fitch] fail to run $prog");
	print $fh "u\n" if ($tree_file);
	print $fh "y\n";
	close($fh);
	my $rst = read_file("outtree");
	my $log = read_file("outfile");
	unlink("infile", "outfile", "intree", "outtree");
	chdir($cwd);
	rmdir($tmp_dir);
	$rst =~ s/pZQa(\d{5})/$array[$1]/g;
	$log =~ s/pZQa(\d{5})/$array[$1]/g;
	return ($rst, $log);
}
sub mfa2phy
{
	my $mfa = shift;
	my $phy = shift;
	my $is_modify_gap = (@_)? shift : 1;
	my $fh_mfa = gopen($mfa);
	$phy = ">$phy" if (!ref($phy) && $phy !~ /^>/);
	my $fh_phy = gopen($phy);
	my $tag = 'pZQa';
	my %hash;
	my @array;
	# read MFA
	$/ = ">"; <$fh_mfa>; $/ = "\n";
	while (<$fh_mfa>) {
		my @t = split;
		push(@array, $t[0]);
		$/ = ">";
		$_ = <$fh_mfa>;
		chomp; $/ = "\n"; chomp;
		s/\s//g;
		tr/-/?/ if ($is_modify_gap);
		$hash{$t[0]} = $_;
	}
	close($fh_mfa);
	# check
	my $len = -1;
	foreach my $p (keys %hash) {
		if ($len < 0) {
			$len = length($hash{$p});
		} elsif ($len != length($hash{$p})) {
			warn("[mfa2phy] variable length!");
			return;
		}
	}
	# write PHYLIP
	print $fh_phy " ", scalar(@array), " ", length($hash{$array[0]}), "\n";
	for (my $i = 0; $i < $len; $i += 50) {
		for (my $j = 0; $j < @array; ++$j) {
			if ($i == 0) {
				printf $fh_phy ("%s%.5d ", $tag, $j);
			} else {
				print $fh_phy "          ";
			}
			print $fh_phy substr($hash{$array[$j]}, $i, 50), "\n";
		}
		print $fh_phy "\n";
	}
	close($fh_phy);
	return @array;
}
sub five_digit
{
	my $i = shift;
	return sprintf("%.5d", $i);
}

########## CODES FROM treefam::generic ############

sub dirname
{   
    my $prog = shift;
    return '.' if (!($prog =~ /\//));
    $prog =~ s/\/[^\s\/]$//g;
    return $prog;
}
sub which
{   
    my $file = shift;
    my $path = (@_)? shift : $ENV{PATH};
    return if (!defined($path));
    foreach my $x (split(":", $path)) {
        $x =~ s/\/$//;
        return "$x/$file" if (-x "$x/$file");
    }
    return;
}
sub gwhich
{
    my $progname = shift;
    my $addtional_path = shift if (@_);
    my $dirname = &dirname($0);
    my $tmp;

    chomp($dirname);
    if ($progname =~ /^\// && (-x $progname)) {
        return $progname;
    } elsif (defined($addtional_path) && ($tmp = &which($progname, $addtional_path))) {
        return $tmp;
    } elsif (-x "./$progname") {
        return "./$progname";
    } elsif (defined($dirname) && (-x "$dirname/$progname")) {
        return "$dirname/$progname";
    } elsif (($tmp = &which($progname))) {
        return $tmp;
    } else {
        warn("[generic::gwhich] fail to find executable $progname anywhere.");
        return;
    }
}
sub gopen
{
    my $f = shift;
    return $f if (ref($f) eq 'GLOB');
    if (!ref($f)) {
        my $fh;
        unless (open($fh, $f)) {
            warn("[treefam::generic::open] fail to open file $f");
            return;
        }
        return $fh;
    }
}
sub read_file
{
    my ($file) = @_;
    my $fh = gopen($file);
    $_ = join("", <$fh>);
    close($fh);
    return $_;
}
sub write_file
{
	my ($file, $content) = @_;
	$file = ">$file" if (!ref($file) && $file !~ /^>/); # a file name
	my $fh = gopen($file);
	print $fh $content;
	close($fh);
}
