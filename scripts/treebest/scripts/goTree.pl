#!/usr/local/bin/perl -w
# Copyright (c) BGI
# Program       : goTree.pl
# Author        : Liu Tao <liutao@genomics.org.cn>
# Program Data  : 2004-11-17
# Modifier      : Liu Tao <liutao@genomics.org.cn>
# Last Modified :
# Description   :
#
# 2005-04-19 lh3
#
#     *  for nucleotide
#     *  improve which

use strict;
use Getopt::Long;
use Cwd;

my $CURRENTDIR = getcwd();
my $VER = '1.1';

my $KILLTIME = 300;
my $TREEPROG = 'puzzle';
my $TIMEDEXE = 'timedexe';
                             # ---------------------------------------------------- #
my $TRANSINP = "zUm";        # You can change the tag prefix but please also change #
my $SQNUMLMT = 1e6;          # $SQNUMLMT at the same time, to make sure the length  #
                             # of the sum of these two variables add up to 10.      #
                             # ---------------------------------------------------- #

# PHYML DEFAULT OPTIONS #
my $SEQTYP = 1;      # Seq type: Protein                           # 1 datatype
my $SEQFMT = 'i';    # Seq format: interleave                      # 2 sequence format
my $NBDATS = 1;      # number of date set                          # 3 nb data sets
my $NBBOOT = 0;      # num of bootstrap date sets                  # 4 nb bootstrapped data sets
my $SUBMOD = 'WAG';  # substitution model                          # 5 substitution model
my $RATIO  = '4.0';  # 6 ts/tv ratio (4.0), for nucleotide
my $PROPIV = '0.0';  # no invarible site                           # 7 prop. invariable sites
my $NBCATG = 1;      # number of categories                        # 8 nb categories
my $GMPARA = '1.0';  # Gamma parameter                             # 9 gamma parameter or `e' for estimation
my $OUTFMT = 'BIONJ';# Output file/format: distance-based          # 10 starting tree
my $OPMOPT = 'y y';  # Optimise starting tree options: no optimise # 11/12 optimization


my %options;
GetOptions(\%options, "f=s", "p=s", "t=i", "z=s", "n", "m=s", "r=s", "g=s", "e=s");
$options{f} and $options{p} or usage();
my $fafile = $options{f};
my $prefix = $options{p};

$TIMEDEXE = $options{e} if (defined($options{e}));
$options{t} and $KILLTIME = $options{t};
$TREEPROG = &which((defined $options{z}) ? $options{z} : $TREEPROG);
$TIMEDEXE = &which((defined $options{e}) ? $options{e} : $TIMEDEXE);
my $is_nucl = (defined $options{n})? 1 : 0;
if ($is_nucl) {
	$SEQTYP = 0;
	$SUBMOD = 'HKY'; # default model for nucleotide
}
$RATIO = $options{r} if (defined($options{r}));
$SUBMOD = $options{m} if (defined($options{m}));
$GMPARA = $options{g} if (defined($options{g}));

#checkprg($TREEPROG);
#checkprg($TIMEDEXE);

my ($rRevFa, $rNamePair, $FaNum, $FaMaxLen) = readfa($fafile, $SQNUMLMT, $TRANSINP);
my $outstatus = transfa2phy($rRevFa, $FaNum, $FaMaxLen, $prefix);

die "Error: While output phy file.\n" if ($outstatus != 1);

if ($TREEPROG =~ /phyml/i) {                 # deal with phyml #
	my $tmp_str = (!$is_nucl)? $SUBMOD : join(" ", $SUBMOD, $RATIO);
	my $PHYMLOPT = join(" ", $SEQTYP, $SEQFMT, $NBDATS, $NBBOOT, $tmp_str, $PROPIV, $NBCATG, $GMPARA, $OUTFMT, $OPMOPT);

	my $use_cmd2 = "$TIMEDEXE $KILLTIME $TREEPROG $prefix.phy $PHYMLOPT >/dev/null 2>&1";
	my $phyml_postfix = "_phyml_tree.txt";
	rundeal($use_cmd2, $phyml_postfix, $TRANSINP, $rNamePair);
}
else {          # Deal with puzzle one #
	my $tmp_str = (int($GMPARA) == 1)? '' : "w c $GMPARA";
	my $use_cmd = "echo $tmp_str y | $TIMEDEXE $KILLTIME $TREEPROG $prefix.phy >/dev/null 2>&1";
	print "$use_cmd\n";
	my $puzzle_postfix = ".tree";
	rundeal($use_cmd, $puzzle_postfix, $TRANSINP, $rNamePair);
}


# Run TREEPROG and deal with the results #
sub rundeal {
	my ($exec_cmd, $postfix, $transinput, $rnmpair) = @_;
	my $pid;
	my $status;
	if (!defined ($pid = fork())) {
		die "Error: Fail to fork!\n";
	}
	elsif ($pid != 0) {
		wait ();
		$status = $?;
	}
	else {
		exec ($exec_cmd);
	}

	if ($status == 0) {
		open (TR, $prefix.".phy".$postfix) || die "Error: Cannot open $prefix.phy.tree.$!\n";
		open (NH, ">$prefix.nh") || die "Error Cannot creat $prefix.nh. $!\n";
		
		while (my $ln = <TR>) {
			$ln =~ s/($transinput\d+)/$$rnmpair{$1}/g;
			print NH $ln;
		}
		close TR;
		close NH;
	}
	elsif ($status == 256) {
		print STDERR "Warning: Timeout while running program $TREEPROG.\n";
	}
	else {
		print STDERR "Warning: Meet an error while running program $TIMEDEXE.\n";
	}
	unlink <$prefix.phy*>;
}

#
# locate a excutable program
#
sub which
{
	my ($progname) = @_;
	my $dirname = &dir_name($0);
	my $tmp;

	chomp($dirname);
	if ($progname =~ /^\// && (-x $progname)) {
		return $progname;
	} elsif (-x "./$progname") {
		return "./$progname";
	} elsif (-x "$dirname/$progname") {
		return "$dirname/$progname";
	} elsif (($tmp = &my_which($progname)) ne "") {
		return $tmp;
	} else {
		warn("[which()] fail to find executable $progname anywhere.");
		return;
	}
}
sub dir_name
{
	my ($prog) = @_;
	return '.' if (!($prog =~ /\//));
	$prog =~ s/\/[^\s\/]+$//;
	return $prog;
}
sub my_which
{
	my ($file) = @_;
	return "" if (!defined($ENV{PATH}));
	foreach my $x (split(":", $ENV{PATH})) {
		$x =~ s/\/$//;
		return "$x/$file" if (-x "$x/$file");
	}
}


# Check whether the TREEPROG exists #
# If no exists, throw an error      #
sub checkprg {
	my $filepath = $_[0];
	if (!(-e $filepath and -x $filepath)) {
		die "The program path $filepath is invalid. Maybe unexecutable.\n";
	}
}
		

# Read the fasta file and then reverse their tag #
sub readfa {
	my ($filenm, $seqnumlimit, $transinput) = @_;

	open (FA, $filenm) || die "Error: Cannot open $filenm. $!\n";
	
	my %allfa = ();
	my %falen = ();
	my $tagtmp = "";
	my $seqtmp = "";
	my $famaxlen = 0;
	my $lentmp = 0;
	my $fanum  = 0;

	# Read original fasta file        #
	# Calculate the number and length #

	while (my $line = <FA>) {
		if ($line =~ /^>(\S+)/) {
			my $tempuse = $1;
			if ($seqtmp ne "") {
				$allfa{$tagtmp} = $seqtmp;
				$falen{$tagtmp} = $lentmp;
				if ($lentmp > $famaxlen) {
					$famaxlen = $lentmp;
				}
			}
			$tagtmp = $tempuse;
			$seqtmp = "";
			$lentmp = 0;
			$fanum ++;
			next;
		}
		$line =~ s/\s+//g;
		$seqtmp .= $line;
		$lentmp += (length $line);
	}
	if ($seqtmp ne "") {
		$allfa{$tagtmp} = $seqtmp;
		$falen{$tagtmp} = $lentmp;
		if ($lentmp > $famaxlen) {
			$famaxlen = $lentmp;
		}
	}
	close FA;

	if ($fanum == 0) {
		die "Error: No available fasta sequence in $filenm.\n";
	}

	# Generate new tag fasta for phy output #
	# Record the pair of tags               #

	my $addchar  = '-';
	my $nameins  = '0';

	my $numlen = length ($seqnumlimit) - 1;
	my $maxwei = length ($fanum);
	my $mindist = $numlen - $maxwei;
	if ($mindist < 0) {
		die "Error: Cannot output all the sequences. Out of boundary\n";
	}

	my %namepair = ();
	my %revfa = ();
	my $Idx = 0;
	foreach my $name (sort keys %falen) {
		$Idx ++;
		
		# Format output seq name #
		my $wei = length ($Idx);
		my $weidist = $numlen - $wei;
		my $newname = $transinput.($nameins x $weidist).$Idx;
		$namepair{$newname} = $name;

		# Add chars to shorter sequences to make coordinate. #
		my $fadist = $famaxlen - $falen{$name};
		$revfa{$newname} = $allfa{$name}.($addchar x $fadist);
	}

	return (\%revfa, \%namepair, $fanum, $famaxlen);
}

# Output the fasta file in phylip format     #
# Like the result of seqret in phylip format #
sub transfa2phy {
	my ($rfa, $fanum, $famaxlen, $outpre) = @_;
	my $sepspace = ' ';

	open (PHY, ">".$outpre.".phy") || die "Error: Can not creat $outpre. $!\n";
	print PHY " $fanum $famaxlen\n";

	# Print the tag line #
	my $preline = $sepspace x 10;
	my @fakeys = (sort keys %$rfa);
	my $blocknum = $famaxlen / 50;
	for (my $lnum = 0; $lnum < $blocknum; $lnum ++) {
		foreach my $tag (@fakeys) {
			my $lnbgn = ($lnum == 0) ? $tag : $preline;
			printf PHY ("%-10s", $lnbgn);
			my $tempfa = substr ($$rfa{$tag}, 0, 50, "");
			my @tmplnb = ();
			for (my $i = 0; $i < 50; $i += 10) {
				my $blockstr = substr ($tempfa, 0, 10, "");
				push (@tmplnb, $blockstr);
			}
			my $tempjn = join (" ", @tmplnb);
			$tempjn =~ s/\s+$//;
			print PHY $tempjn."\n";
		}
		print PHY "\n";
	}
	close PHY;
	return 1;
}
	

sub usage {
	print <<EOHIPPUS;

Usage: perl $0 <options>
Version: $VER

Options:
       <-f FILE>  : Input fasta format sequences.
       <-p STR>   : Output prefix string.

       [-t NUM]   : Timeout limitation number, default $KILLTIME.
       [-z PATH]  : The path of the Tree Program, default will search for "$TREEPROG".

       [-m MODEL] : (phyml) Evolutionary model. By default, HKY for nt and WAG for aa.
       [-r RATIO] : (phyml) Trasition/transversion ratio. Default value is $RATIO.
       [-n]       : (phyml) The input is nucleotide alignment.

       [-g FNUM]  : (puzzle & phyml) Gamma rate. Default value is $GMPARA.
                    (Please note that puzzle and phyml use different scale!!!)

EOHIPPUS
	exit (0);
}
