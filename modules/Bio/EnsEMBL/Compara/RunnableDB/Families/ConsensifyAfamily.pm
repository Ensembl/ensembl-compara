=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Families::ConsensifyAfamily;

# RunnableDB to assemble the consensus annotations on the fly
# (remake of 'consensifier.pl' and 'assemble-consensus.pl' originally written by Abel Ureta-Vidal)

use POSIX;
use strict;
use warnings;
use Bio::EnsEMBL::Compara::Production::AlgorithmDiff qw(LCS);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    my $start_family_id = $self->param_required('family_id');
    my $minibatch       = $self->param('minibatch') || 1;
    my $end_family_id   = $start_family_id+$minibatch-1;

        # get all Uniprot members that would belong to the given family if redundant elements were added:
    my $sql = qq {
        SELECT fm.family_id, m2.source_name, m2.description
          FROM family_member fm, seq_member m1, seq_member m2
         WHERE fm.family_id BETWEEN ? AND ?
           AND fm.seq_member_id=m1.seq_member_id
           AND m1.sequence_id=m2.sequence_id
           AND m2.source_name IN ('Uniprot/SWISSPROT', 'Uniprot/SPTREMBL')
      GROUP BY fm.family_id, m2.seq_member_id
    };

    my $sth = $self->compara_dba->dbc->prepare( $sql, { 'mysql_use_result' => 1 } );
    $sth->execute( $start_family_id, $end_family_id );

        # initialize it to ensure all family_ids are mentioned:
    my %famid2srcname2descs = map { ($_ => { 'Uniprot/SWISSPROT' => [], 'Uniprot/SPTREMBL'  => []}) } ($start_family_id..$end_family_id);

    while( my ($family_id, $source_name, $description) = $sth->fetchrow() ) {
        $description =~ tr/().-/    /;
        push @{ $famid2srcname2descs{$family_id}{$source_name} }, apply_edits(uc $description);
    }
    $sth->finish();

    $self->param('famid2srcname2descs', \%famid2srcname2descs);
}

sub run {
    my $self = shift @_;

    $self->compara_dba->dbc->disconnect_if_idle();

    my $famid2srcname2descs = $self->param('famid2srcname2descs');

    my %description = ();
    my %score       = ();

    foreach my $family_id (sort {$a<=>$b} keys %$famid2srcname2descs) {

        my ($cons_description, $cons_score);

        #This style is more readable
        if (scalar(@{ $famid2srcname2descs->{$family_id}{'Uniprot/SWISSPROT'}})){
            ($cons_description, $cons_score) = consensify($famid2srcname2descs->{$family_id}{'Uniprot/SWISSPROT'})
        }elsif(scalar(@{ $famid2srcname2descs->{$family_id}{'Uniprot/SPTREMBL'}})){
            ($cons_description, $cons_score) = consensify($famid2srcname2descs->{$family_id}{'Uniprot/SPTREMBL'})
        }else{
            ($cons_description, $cons_score) = ();
        }

        ($description{$family_id}, $score{$family_id}) = assemble_consensus($cons_description, int($cons_score));
    }

    $self->param('description', \%description);
    $self->param('score',       \%score);
}

sub write_output {
    my $self = shift @_;

    my $description = $self->param('description');
    my $score       = $self->param('score');

    my $sql = "UPDATE family SET description = ?, description_score = ? WHERE family_id = ?";
    my $sth = $self->compara_dba->dbc->prepare( $sql );

    foreach my $family_id (sort {$a<=>$b} keys %$description) {
        $sth->execute( $description->{$family_id}, $score->{$family_id}, $family_id );
    }
    $sth->finish();
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
                    \{[^}]*\}
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
  my %desc = ();
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
  
  my %lcshash = ();
  my %lcnext  = ();
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
  my @all_cands=sort { length($b) <=> length($a) } keys %lcshash ;
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
}

sub assemble_consensus {
  my ($pre_description, $pre_score) = @_;

            ### deletes to be applied to correct some howlers
            my @deletes = ('FOR\s*$', 'SIMILAR\s*TO\s*$', 'SIMILAR\s*TO\s*PROTEIN\s*$',
                    'SIMILAR\s*TO\s*GENE\s*$','SIMILAR\s*TO\s*GENE\s*PRODUCT\s*$',
                    '\s*\bEC\s*$', 'RIKEN CDNA [A_Z]\d+\s*$', 'NOVEL\s*PROTEIN\s*$',
                    'NOVEL\s*$','C\d+ORF\d+','LIKE'); 

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

            # sanity check on the words:
            foreach my $w (@useless_words) {
              if ( $w =~ /$word_splitter/) {
                die "word '$w' to be matched matches ".
                  "the word_splitter regexp '$word_splitter', so will never match";
              }
            }

  my $annotation='UNKNOWN';
  my $score=0;

  if (defined $pre_description) {
    $annotation=$pre_description;
    $score=$pre_score;
    if ($score < 40) {
      $annotation = 'AMBIGUOUS';
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
  
  my $discarded_flag = 0;
  my $uselessness_output = '';

  if ( $annotation eq ''
       || ($useless >= 1 && $total == 1)
       || $useless > ($total+1)/2 ) {
    $uselessness_output = "$useless/$total;\t$annotation\t$score";
    $discarded_flag++;
    $annotation='UNKNOWN'; 
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

  if (/^BG:.*$/ || /^EG:.*$/ || length($_) <= 2 || /^\w{1}\s\d+\w*$/ || ! /\w{3}/) {
    $_='UNKNOWN';
    $score = 0;
  }
  
  return ($_, $score, $discarded_flag, $uselessness_output);
}

1;
