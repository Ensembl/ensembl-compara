#!/usr/local/ensembl/bin/perl 

# Script to assembl the consensus annotations from different files into
# final ones. It basically takes the SWISS-PROT description consensus if
# there is one, otherwise the SPTREMBL one, and then cleans things up
# (even applies some edits). The reason not to do this straight away in
# consensifier is that the latter takes too much time, so you can't tweak
# scores etc. to obtain acceptable output.
# 

$|=1;
use POSIX;
use strict;
use Getopt::Long;

my $usage=<<END_USAGE;

Usage:
  $0  [options ] file.annotated \\
      file.SWISSPROT-consensus file.SPTREMBL-consensus \\
         > file.families 2> file.discarded

  Discarded annotations are written to stderr

  Note: the order of the consensus files matters: first SWISSPROT, then SPTREMBL

  Options:
   -h          : this message
END_USAGE

my $help = 0;

unless (GetOptions('help' => \$help)) {
  die $usage;
}


if (@ARGV != 3 || $help) { 
  die $usage; 
}

### deletes to be applied to correct some howlers

my @deletes = ('FOR\s*$', 'SIMILAR\s*TO\s*$', 'SIMILAR\s*TO\s*PROTEIN\s*$', 'SIMILAR\s*TO\s*GENE\s*$','SIMILAR\s*TO\s*GENE\s*PRODUCT\s*$', '\s*\bEC\s*$', 'RIKEN CDNA [A_Z]\d+\s*$', 'NOVEL\s*PROTEIN\s*$', 'NOVEL\s*$','C\d+ORF\d+','LIKE'); 

### any complete annotation that matches one of the following, gets
### ticked off completely

my @useless_annots = 
  qw( ^.$  
      ^\d+$ 
      .*RIKEN.*FULL.*LENGTH.*ENRICHED.*LIBRARY.*
    );

### regexp to split the annotations into separate words for scoring:
my $word_splitter='[\/ \t,:]+';

### words that get scored off; the balance of useful/useless words
### determines whether they make it through.
### (these regexps are surrounded by ^ and $ before they're used)

my @useless_words =  # and misspellings, that is
  qw( BG EG BCDNA PROTEIN UNKNOWN FRAGMENT HYPOTHETICAL HYPOTETICAL 
      NOVEL PUTATIVE PREDICTED UNNAMED UNNMAED
      PEPTIDE KDA ORF CLONE MRNA CDNA FOR
      EST
      RIKEN FIS KIAA\d+ \S+RIK IMAGE HSPC\d+ _*\d+ 5\' 3\'
      .*\d\d\d+.*
    );

# remind us 
# warn "todo: replace UNKNOWN with AMBIGUOUS where appropriate\n";

# sanity check on the words:
foreach my $w (@useless_words) {
  if ( $w =~ /$word_splitter/) {
    die "word '$w' to be matched matches ".
      "the word_splitter regexp '$word_splitter', so will never match";
  }
}

my ($cluster_file, $swissprot_consensus, $sptrembl_consensus) = @ARGV;

my %clusters;

if ($cluster_file =~ /\.gz/) {
  open (FILE,"gunzip -c $cluster_file|") || die "$cluster_file$!"; 
} else {
  open (FILE,$cluster_file) || die "$cluster_file$!";
}
while (<FILE>) {
  if (/^\S+\t(\d+)\t(.*)\t.*$/) {
    my ($cluster_id, $seqid) = ($1,$2);
    push(@{$clusters{$cluster_id}},$seqid);
  } else {
    die "bad format for cluster file: $_\n";
  }
}
close FILE;

my (%descriptions, %scores);

# make sure we're read the SPTREMBL first, then override with SWISSPROT
die "$sptrembl_consensus: expecting 'tr' as part of filename: second one should be trembl" 
  unless $sptrembl_consensus =~ /tr/i;
read_consensus($sptrembl_consensus, \%descriptions, \%scores);

# now override with SWISSPROT:
die "$swissprot_consensus: expecting 'sw' as part of filename: first one should be swissprot" 
  unless $swissprot_consensus =~ /sw/i;
read_consensus($swissprot_consensus, \%descriptions, \%scores);

my $final_total=0;
my $discarded=0;
my $n=0;

foreach my $cluster_id (sort numeric (keys(%clusters))) {
  my $annotation="UNKNOWN";
  my $score=0;

  if (defined $descriptions{$cluster_id}) {
    $annotation=$descriptions{$cluster_id};
    $score=$scores{$cluster_id};
    if ($score < 40) {
      $annotation = "AMBIGUOUS";
      $score = 0;
    }
  }
  # apply the deletes:
  foreach my $re (@deletes) { 
    $annotation =~ s/$re//g; 
  }

  my $useless=0;	
  my $total= 1;

  $_=$annotation;
  # see if the annotation as a whole is useless:
  if (grep($annotation =~ /$_/, @useless_annots)) {
    $useless=1000;
  } else {
    # word based checking: what is balance of useful/less words:
    my @words=split(/$word_splitter/,$annotation);
    $total= scalar @words;
    foreach my $word (@words) {
      if ( grep( $word =~ /^$_$/, @useless_words ) ) {
	$useless++;
      }
    }
    $useless += 1 if $annotation =~ /\bKDA\b/;
    # (because the kiloDaltons come with at least one meaningless number)
  }
  
  if ( $annotation eq ''
       || ($useless >= 1 && $total == 1)
       || $useless > ($total+1)/2 ) {
    print STDERR "uselessness: $useless/$total: $cluster_id\t$annotation\t$score\n";
    $discarded++;
    $annotation="UNKNOWN"; 
    $score=0;
  }
  $_=$annotation;
  
  #Apply some fixes to the annotation:
  s/EC (\d+) (\d+) (\d+) (\d+)/EC $1\.$2\.$3\.$4/;
  s/EC (\d+) (\d+) (\d+)/EC $1\.$2\.$3\.-/;
  s/EC (\d+) (\d+)/EC $1\.$2\.-\.-/;
  s/(\d+) (\d+) KDA/$1.$2 KDA/;
  
  s/\s+$//;
  s/^\s+//;

  if (/^BG:.*$/ || /^EG:.*$/ || length($_) <= 2 || /^\w{1}\s\d+\w*$/) {
    $_="UNKNOWN";
    $score = 0;
  }
  
  my @members = @{$clusters{$cluster_id}};
  $final_total +=  int(@members);
  print "$cluster_id\t$_\t$score\n";
}                                       # foreach $cluster_id

print STDERR "FINAL TOTAL: $final_total\n";
print STDERR "discarded: $discarded\n";

sub numeric { $a <=> $b}

### read consensus annotations and scores into hashes
sub read_consensus { 
  my($file, $deschash, $scorehash)=@_;
  my (%hash, %score);
  
  open FILE, $file || die "$file:$!";
  
  while (<FILE>) {
    my ($id, $desc, $score) = (/^(\d+)\t>>>(.*)<<<\t(\d+)/);
    if (0 && # for debugging purposes
	defined $deschash->{$id}) {
      warn "for $id, replacing ".$deschash->{$id}." (score ".$scorehash->{$id}.") with $desc (score $score)\n";
    }
    $deschash->{$id}=$desc;
    $scorehash->{$id}=$score;
  }
  close FILE;
  undef;
}

