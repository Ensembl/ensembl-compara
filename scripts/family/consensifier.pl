#!/usr/local/bin/perl
# $Id$
# 
# Derives consensus annotations from descriptions in a database, using a
# longest common substring approach. The final descriptions are
# tweaked/cleaned up in assemble-consensus.pl, simply because
# consensifier.pl takes so long. In other words, don't tweak too much
# here. 
#

use strict;
use Getopt::Long;
use Algorithm::Diff qw(LCS);

main();
exit(0);

sub main {
    my @allowed_dbs= qw(Uniprot/SWISSPROT Uniprot/SPTREMBL);

    my $usage=<<END_USAGE;

Usage:
  $0 -d database file.annotated > outfile
  Options:
   -h          : this message
   -d DATABASE : the database to use (allowed: @allowed_dbs)

END_USAGE

    my $help = 0;
    my $database;

    unless (GetOptions('help' => \$help,
               'd=s' => \$database)) {
      die $usage;
    }

    $database = uc $database;

    if (@ARGV != 1 ||
        $help ||
        ! grep($database, @allowed_dbs)) {
      die $usage; 
    }

    $|=1;

    my ($file) = @ARGV;
    die "$file: can't open" unless -f $file;
    my $goners='().-';
    my $spaces= ' ' x length($goners);
    my $filter = "tr '$goners' '$spaces' < $file";

    open FILE, "$filter | " || die "$filter: $!";

    my %family_id2descriptions;

    while (<FILE>) {
      /^(\S+)\t(\d+)\t(\S+)\t(.*)$/;
      my ($db,$family_id,$protein,$desc) = ($1,$2,$3,$4);
      $desc =~ s/\s+/ /g;

      if (uc $db eq $database) {
        $desc = &apply_edits(uc $desc);
        push(@{$family_id2descriptions{$family_id}},$desc);
      }
    }

    close FILE;

    foreach my $family_id (sort sort_num(keys(%family_id2descriptions))) {

        my ($description, $percentage) = consensify($family_id2descriptions{$family_id});

        print "$family_id\t>>>${description}<<<\t$percentage\n";
    }

}

# -------------------------- functional subroutines ----------------------------------

sub as_words { 
    #add ^ and $ to regexp
    my (@words) = @_;
    my @newwords=();

    foreach my $word (@words) { 
      push @newwords, "(^|\\s+)$word(\\s+|\$)"; 
    }
    return @newwords;
}

sub apply_edits  { 
  local($_) = @_;
  
  my @deletes = (qw(FOR\$
		    SIMILAR\s+TO\$
		    SIMILAR\s+TO\s+PROTEIN\$
		    RIKEN.*FULL.*LENGTH.*ENRICHED.*LIBRARY
		    CLONE:[0-9A-Z]+ FULL\s+INSERT\s+SEQUENCE
		    \w*\d{4,} HYPOTHETICAL\s+PROTEIN
		    IN\s+CHROMOSOME\s+[0-9IVX]+ [A-Z]\d+[A-Z]\d+\.{0,1}\d*),
		 &as_words(qw(NOVEL PUTATIVE PREDICTED 
			      UNNAMED UNNMAED ORF CLONE MRNA 
			      CDNA EST RIKEN FIS KIAA\d+ \S+RIK IMAGE HSPC\d+
			      FOR HYPOTETICAL HYPOTHETICAL PROTEIN ISOFORM)));
 
  foreach my $re ( @deletes ) { 
    s/$re/ /g; #space just for the the as_words regexs, to put back the spaces.
  }
  
  #Apply some fixes to the annotation:
  s/EC (\d+) (\d+) (\d+) (\d+)/EC_$1.$2.$3.$4/;
  s/EC (\d+) (\d+) (\d+)/EC_$1.$2.$3.-/;
  s/EC (\d+) (\d+)/EC_$1.$2.-.-/;
  s/(\d+) (\d+) KDA/$1.$2 KDA/;
  s/\s*,\s*/ /g;
  s/\s+/ /g;
  
  $_;
}


sub consensify {
  my($original_descriptions) = @_;

  my $best_annotation = '';

  my $total_members = scalar(@$original_descriptions);
  my $total_members_with_desc = grep(/\S+/, @$original_descriptions);

  ### OK, first a list of hacks:
  if ( $total_members_with_desc ==0 )  { # truly unknown
    return ('UNKNOWN', 0);
  }
  
  if ($total_members == 1) {
    $best_annotation = $original_descriptions->[0];
    $best_annotation =~ s/^\s+//; 
    $best_annotation =~ s/\s+$//; 
    $best_annotation =~ s/\s+/ /;
    if ($best_annotation eq '' || length($best_annotation) == 1) {
      return ('UNKNOWN', 0);
    } else { 
      return ($best_annotation, 100);
    }
  }

  if ($total_members_with_desc == 1)  { # nearly unknown
    ($best_annotation) = grep(/\S+/, @$original_descriptions);
    my $perc= int($total_members_with_desc/$total_members*100);
    $best_annotation =~ s/^\s+//;
    $best_annotation =~ s/\s+$//;
    $best_annotation =~ s/\s+/ /;
    if ($best_annotation eq '' || length($best_annotation) == 1) { 
      return ('UNKNOWN', 0);
    } else {  
      return ($best_annotation, $perc);
    } 
  }

  # all same desc:
  my %desc = undef;
  foreach my $desc (@$original_descriptions) {
    $desc{$desc}++;     
  }
  if  ( (keys %desc) == 1 ) {
    ($best_annotation) = keys %desc;
    my $n = grep($_ eq $best_annotation, @$original_descriptions);
    my $perc= int($n/$total_members*100);
    $best_annotation =~ s/^\s+//;
    $best_annotation =~ s/\s+$//;
    $best_annotation =~ s/\s+/ /;
    if ($best_annotation eq '' || length($best_annotation) == 1) {  
      return ('UNKNOWN', 0);
    } else {   
      return ($best_annotation, $perc);
    }  
  }
  # this should speed things up a bit as well 
  
  my %lcshash = undef;
  my %lcnext  = undef;
  my @array   = @$original_descriptions;
  while (@array) {
    # do an all-against-all LCS (longest commong substring) of the
    # descriptions of all members; take the resulting strings, and
    # again do an all-against-all LCS on them, until we have nothing
    # left. The LCS's found along the way are in lcshash.
    #
    # Incidentally, longest common substring is a misnomer, since it
    # is not guaranteed to occur in either of the original strings. It
    # is more like the common parts of a Unix diff ... 
    for (my $i=0;$i<@array;$i++) {
      for (my $j=$i+1;$j<@array;$j++){
	my @list1=split /\s+/,$array[$i];
	my @list2=split /\s+/,$array[$j];
	my @lcs=LCS(\@list1,\@list2);
	my $lcs=join(" ",@lcs);
	$lcs =~ s/^\s+//;
	$lcs =~ s/\s+$//;
	$lcs =~ s/\s+/ /;
	$lcshash{$lcs}=1;
	$lcnext{$lcs}=1;
      }
    }
    @array=keys(%lcnext);
    undef %lcnext;
  }

  my ($best_score, $best_perc)=(0, 0);
  my @all_cands=sort sort_len_desc keys %lcshash ;
  foreach my $candidate_consensus (@all_cands) {
    next unless (length($candidate_consensus) > 1);
    my @temp=split /\s+/,$candidate_consensus;
    my $length=@temp;               # num of words in annotation
    
    # see how many members of cluster contain this LCS:
    
    my ($lcs_count)=0;
    foreach my $orig_desc (@$original_descriptions) {
      my @list1=split /\s+/,$candidate_consensus;
      my @list2=split /\s+/,$orig_desc;
      my @lcs=LCS(\@list1,\@list2);
      my $lcs=join(" ",@lcs);  
      
      if ($lcs eq $candidate_consensus
	  || index($orig_desc,$candidate_consensus) != -1 # addition;
	  # many good (single word) annotations fall out otherwise
	 ) {
	$lcs_count++;
	
	# Following is occurs frequently, as LCS is _not_ the longest
	# common substring ... so we can't use the shortcut either
	
	# if ( index($orig_desc,$candidate_consensus) == -1 ) {
	#   warn "lcs:'$lcs' eq cons:'$candidate_consensus' and
	# orig:'$orig_desc', but index == -1\n" 
	# }
      }
    }	
    
    my $perc_with_desc=($lcs_count/$total_members_with_desc)*100;
    my $perc= $lcs_count/$total_members*100; 
    my $score=$perc + ($length*14); # take length into account as well
    $score = 0 if $length==0;
    if (($perc_with_desc >= 40) && ($length >= 1)) {
      if ($score > $best_score) {
	$best_score=$score;
	$best_perc=$perc;
	$best_annotation=$candidate_consensus;
      }
    }
  }                                   # foreach $candidate_consensus
  
  if  ($best_annotation eq  "" || $best_perc < 40)  {
    $best_annotation = 'AMBIGUOUS';
    $best_perc = 0;
  }
  $best_annotation =~ s/^\s+//;
  $best_annotation =~ s/\s+$//;
  $best_annotation =~ s/\s+/ /;
  
  return ($best_annotation, $best_perc);
}                                       # consensify()

sub sort_num { $a <=> $b };

sub sort_len_desc { length($b) <=> length($a) };
