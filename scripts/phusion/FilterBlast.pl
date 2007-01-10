#!/usr/local/ensembl/bin/perl -w

# This script, originally written by Jim Mullikin, then called cigar.pl was renamed to FilterBlast.pl
# and adapted to also filter wutblastx outputs

use strict;
use Getopt::Long;

my $usage = "
$0 [options] SpeciesTag MinScore
e.g $0 Hs 300

-h display this help menu
-debug display in STDERR debugging info

-p blastn|tblastx (default: blastn)
-RangeAroundMedian integer (default: 300000)
-minActLen integer (default: 3000)
-GapLengthPortion integer (default: 10)
-StdDevAmplitude integer (default: 3)

-noMedianFilter avoid both median and std dev filtering steps
-noStdDevFilter avoid only std dev filtering step

";

my $p = "blastn";
my $RangeAroundMedian = 300000;
my $minActLen = 3000;
my $GapLengthPortion = 10; # 1/10th
my $StdDevAmplitude = 3;
my $help = 0;
my $debug = 0;

my $noMedianFilter = 0;
my $noStdDevFilter = 0;

GetOptions('h' => \$help,
	   'debug' => \$debug,
	   'p=s' => \$p,
	   'RangeAroundMedian=i' => \$RangeAroundMedian,
	   'minActLen=i' => \$minActLen,
	   'GapLengthPortion=i' => \$GapLengthPortion,
	   'StdDevAmplitude' => \$StdDevAmplitude,
	   'noMedianFilter' => \$noMedianFilter,
	   'noStdDevFilter' => \$noStdDevFilter);

if ($help) {
  print $usage;
  exit 0;
}

unless (scalar @ARGV >= 2) {
  print $usage;
  warn "You should specify at least the 2 minimum arguments
EXIT 1\n";
  exit 1;
}

my $org = shift;
my $minscore = shift;
my $Q = ""; # Query name
my $Schr = ""; # Subject chromosome name
my $Spos = ""; # Subject chromosome offset position
my $Sst = 0; # Subject start
my $Sen = 0; # Subject end
my $Qst = 0; # Query start
my $Qen = 0; # Query end
my $Qs = ""; # Query sequence
my $Ss = ""; # Subject sequence

my @Matches; # Matches array containing MatchHashRef
my $MatchHashRef; # Hash defining a match

## STEP 1 parsing blast output. Each HSP stored as a hash in a array (@mi)

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
      $MatchHashRef->{Schr} = $Schr;
      if ($Sst <= $Sen) {
	$MatchHashRef->{Sst} = $Spos+$Sst-1;
	$MatchHashRef->{Sen} = $Spos+$Sen-1;
	$MatchHashRef->{Sorient} = "+";
      } else {
	$MatchHashRef->{Sst} = $Spos+$Sen-1;
	$MatchHashRef->{Sen} = $Spos+$Sst-1;
	$MatchHashRef->{Sorient} = "-";
      }
      $MatchHashRef->{Ss} = $Ss;
      $MatchHashRef->{Qs} = $Qs;
      if($Qst <= $Qen) {
	$MatchHashRef->{Qst} = $Qst;
	$MatchHashRef->{Qen} = $Qen;
	$MatchHashRef->{orient} = "+";
      } else {
	$MatchHashRef->{Qst} = $Qen;
	$MatchHashRef->{Qen} = $Qst;
				$MatchHashRef->{orient} = "-";
      }
      push @Matches, $MatchHashRef;
    }
    $MatchHashRef = {};
    $MatchHashRef->{score} = $1;
    $Sst = 0;
    $Sen = 0;
    $Qst = 0;
    $Qen = 0;
    $Qs = "";
    $Ss = "";
    next;
  }
  if (/^ Identities = \S+\s+\((\d+)%\),\s+/) {
    $MatchHashRef->{identity} = $1;
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
  $MatchHashRef->{Schr} = $Schr;
  if ($Sst <= $Sen) {
    $MatchHashRef->{Sst} = $Spos+$Sst-1;
    $MatchHashRef->{Sen} = $Spos+$Sen-1;
    $MatchHashRef->{Sorient} = "+";
  } else {
    $MatchHashRef->{Sst} = $Spos+$Sen-1;
    $MatchHashRef->{Sen} = $Spos+$Sst-1;
    $MatchHashRef->{Sorient} = "-";
  }
  $MatchHashRef->{Ss} = $Ss;
  $MatchHashRef->{Qs} = $Qs;
  if($Qst <= $Qen) {
    $MatchHashRef->{Qst} = $Qst;
    $MatchHashRef->{Qen} = $Qen;
    $MatchHashRef->{orient} = "+";
  } else {
    $MatchHashRef->{Qst} = $Qen;
    $MatchHashRef->{Qen} = $Qst;
    $MatchHashRef->{orient} = "-";
  }
  push @Matches, $MatchHashRef;
}

## END STEP 1

## STEP 2 Defining the winning chromosome

my @RelevantMatches = ();
my %vote = ();
my %MatchesIndexPerSchrSorient = ();

print STDERR "#macthes for query $Q: ",scalar @Matches,"\n" if ($debug);

foreach (sort { $b->{score} <=> $a->{score} } @Matches) { # sorting by highest score
  my %r = %{$_};
  next if $r{score} < $minscore;
  push @{$MatchesIndexPerSchrSorient{$r{Schr}.$r{orient}}}, $_;
  my $Scm = int(($r{Sst}+$r{Sen})/2);
  my $Qcm = int(($r{Qst}+$r{Qen})/2);
  my $covered = 0;
  foreach (@RelevantMatches) {
    if($Scm > $_->{Sst} and $Scm < $_->{Sen} ||
       $Qcm > $_->{Qst} and $Qcm < $_->{Qen}) {
      $covered = 1;
      last;
    }
  }
  next if $covered;
  $vote{$r{Schr}.$r{orient}} += $r{score};
  push @RelevantMatches, $_;
}

@Matches = undef; # for garbage collection;
@RelevantMatches = ();

my $winC;
foreach (keys %vote) {
  if (! defined $winC or $vote{$winC} < $vote{$_}) {
    $winC = $_;
  } else {
    $MatchesIndexPerSchrSorient{$_} = undef; # for garbage collection;
  }
}

unless (defined $winC) {
  print STDERR "No winC for query $Q\n" if ($debug);
  exit 0;
}

print STDERR "winC for query $Q: ",$winC,"\n" if ($debug);
## END STEP 2

## STEP 3 Defining the median position of HSP on the winning chromosome
##        and the range min and max around the median with $RangeAroundMedian

my $w = 0.0;
my $wt = 0.0;
my @median = ();



foreach (sort { $b->{score} <=> $a->{score} } @{$MatchesIndexPerSchrSorient{$winC}}) {
  my %r = %{$_};
  my $Scm = int(($r{Sst}+$r{Sen})/2);
  my $Qcm = int(($r{Qst}+$r{Qen})/2);
  my $covered = 0;
  foreach (@RelevantMatches) {
    if($Scm > $_->{Sst} and $Scm < $_->{Sen} ||
       $Qcm > $_->{Qst} and $Qcm < $_->{Qen}) {
      $covered = 1;
      last;
    }
  }
  next if $covered;
  push @median,$Scm;
  push @RelevantMatches,$_;
}

if ($noMedianFilter) {
  print_out_matches(\@RelevantMatches,0,$#RelevantMatches);
  exit 0;
}

@RelevantMatches = ();

if (@median == 0) {
  warn "size of @median == 0, should never happen!!!\n
EXIT 2";
  exit 2;
}

@median = sort {$a <=> $b} @median;
my $len = @median;
my $median = $median[int($len/2)];
my $min = $median - $RangeAroundMedian;
my $max = $median + $RangeAroundMedian;

## END STEP 3

## STEP 4 Now keeping in the new array (@RelevantMatches) only HSP >= min_score, on the winning chromosome
##        and the median range defined in step 3
##        Defining the average(mean) position of HSP on the winning chromosome, each HSP position
##        weighted by its own score, and defining then standard deviation.

foreach (sort { $b->{score} <=> $a->{score} } @{$MatchesIndexPerSchrSorient{$winC}}) {
  my %r = %{$_};
  my $Scm = int(($r{Sst}+$r{Sen})/2);
  next if ($Scm < $min or $Scm > $max);
  my $Qcm = int(($r{Qst}+$r{Qen})/2);
  my $covered = 0;
  foreach (@RelevantMatches) {
    if($Scm > $_->{Sst} and $Scm < $_->{Sen} ||
       $Qcm > $_->{Qst} and $Qcm < $_->{Qen}) {
      $covered = 1;
      last;
    }
  }
  next if $covered;
  $wt += ($r{Sst}+$r{Sen})/2*$r{score};
  $w += $r{score};
  push @RelevantMatches, $_;
}


print STDERR "#matches after median filtering: ",scalar @RelevantMatches,"\n" if ($debug);

if ($noStdDevFilter) {
  print_out_matches(\@RelevantMatches,0,$#RelevantMatches);
  exit 0;
}

my $mean = $wt/$w;
my $stdev = 0.0;
foreach (@RelevantMatches) {
  my %r = %{$_};
  $stdev += ((($r{Sst}+$r{Sen})/2 - $mean)**2.0) * $r{score};
  printf STDERR "individual stdev: %f score: %d\n",(($r{Sst}+$r{Sen})/2 - $mean),$r{score} if ($debug);
}
$stdev = (($stdev/$w)**0.5);
$min = $mean - $StdDevAmplitude*$stdev;
$max = $mean + $StdDevAmplitude*$stdev;
printf STDERR "Scm mean: %d stdev: %f\n",$mean,$stdev if ($debug);

## END STEP 4

## STEP 5 Defining the starting and ending point for dumping
##        

@RelevantMatches = sort { $a->{Sst} <=> $b->{Sst} } @RelevantMatches;

my $start = 0;
my $actLen = 0;
for (my $i=0; $i < $#RelevantMatches; $i++) {
  my %r = %{$RelevantMatches[$i]};
  my %n = %{$RelevantMatches[$i + 1]};
  $actLen += $r{Sen} - $r{Sst};
  my $nextGap = $n{Sst} - $r{Sen};
  print STDERR "actLen: $actLen nextGap: $nextGap start: $start\n" if ($debug);
  my $Scm = ($r{Sst}+$r{Sen})/2;
  if($Scm < $min or ($actLen < $minActLen and $actLen < $nextGap/$GapLengthPortion)) {
    $actLen = 0;
    $start = $i+1;
    next;
  }
}

my $end = $#RelevantMatches;
$actLen = 0;
for (my $i = $#RelevantMatches; $i > $start; $i--) { 
  my %r = %{$RelevantMatches[$i]};
  my %p = %{$RelevantMatches[$i - 1]};
  $actLen += $r{Sen} - $r{Sst};
  my $nextGap = $r{Sst} - $p{Sen};
  print STDERR "actLen: $actLen nextGap: $nextGap end: $end\n" if ($debug);
  my $Scm = ($r{Sst}+$r{Sen})/2;
  if($Scm > $max or ($actLen < $minActLen and $actLen < $nextGap/$GapLengthPortion)) {
    $actLen = 0;
    $end = $i-1;
    next;
  }
}
 
print STDERR "#matches after StdDev filtering: ",$end-$start+1,"\n" if ($debug);
print_out_matches(\@RelevantMatches,$start,$end);

## END STEP 5

sub print_out_matches {
  my ($MatchesArrayRef,$IndexStart,$IndexEnd) = @_;
  
  for(my $i = $IndexStart; $i <= $IndexEnd; $i++) {
    my %r = %{$MatchesArrayRef->[$i]};
    unless (defined $r{orient}) {
      warn "orient hash key not set for this particular HSP,
$Q:$r{Qst}-$r{Qen},$r{Schr},$r{Sst},$r{Sen},$r{score},$r{identity} !!!
EXIT 3\n";
      exit 3;
    }
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
}

sub cigar_gen {
  my ($q,$s) = @_;
  my @q = split //,$q;
  my @s = split //,$s;
  my $i = 0;
  my @ret = ();
  for (; $i <= $#q; $i++) {
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
  my $c = 0;
  my $ret = "";
  for ($i=1; $i <= $#ret; $i++) {
    if ($ret[$i] eq $ret[$i-1]) {
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
