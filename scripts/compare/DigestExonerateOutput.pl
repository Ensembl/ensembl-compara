#!/usr/local/bin/perl -w

use strict;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::FeatureFactory;
use Bio::SeqIO;
use Getopt::Long;

$| = 1;

my $qy_host = 'ecs1a.sanger.ac.uk';
my $qy_dbname = 'mouse_sc011015_alistair';
my $qy_dbuser = 'ensro';
my $qy_static_type = "sanger_20011015_2";

my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $qy_host,
					     -user => $qy_dbuser,
					     -dbname => $qy_dbname);

while (defined (my $exonerate_output_file = shift @ARGV)) {
  my %frag_hits;
  open F, $exonerate_output_file || die "Could not open $exonerate_output_file; $!.\n";
  print STDERR "$exonerate_output_file open...\n";
  my ($qy_frag_id,$tg_contig_id,$score);
  while (defined (my $line = <F>)) {
    chomp $line;
    #cigar: 11.958792.959291 290 500 - AC007006.3.1.112027 108878 109088 + 996.00 M 210
#    my ($qy_frag_id,$tg_contig_id,$score);
    if ($line =~ /^cigar:\s+(\S+)\s+(\d+)\s+(\d+)\s+([+-])\s+(\S+)\s+(\d+)\s+(\d+)\s+([+-])\s+(\d+\.\d+)\s+.*$/) {
      my ($qname,$qstart,$qend,$qstrand,$hname,$hstart,$hend,$hstrand,$score) = ($1,$2,$3,$4,$5,$6,$7,$8,$9);
#      ($qy_frag_id,$tg_contig_id,$score) = ($1,$2,$3);

      $score = int($score);
      if ($qstrand eq "+") {$qstrand = 1}
      if ($qstrand eq "-") {$qstrand = -1}
      if ($hstrand eq "+") {$hstrand = 1}
      if ($hstrand eq "+") {$hstrand = -1}

      my $fp = Bio::EnsEMBL::FeatureFactory->new_feature_pair();

      $fp->start($qstart + 1);
      $fp->end($qend);
      $fp->strand($qstrand);
      $fp->seqname($qname);
      $fp->hstart($hstart + 1);
      $fp->hend($hend);
      $fp->hstrand($hstrand);
      $fp->hseqname($hname);
      $fp->score($score);
      push @{$frag_hits{$qname}{$hname}}, $fp;
#      print $line,"\n";;
    } elsif ($line =~ /^(\S+)\s+(\S+)\s+(\d+)$/) {
      ($qy_frag_id,$tg_contig_id,$score) = ($1,$2,$3);
    }
  }
  close F;
  print STDERR "...closed $exonerate_output_file\n";
  foreach my $qname (sort keys %frag_hits) {
    my $highest_score;
    my $highest_hname;
    foreach my $hname (sort keys %{$frag_hits{$qname}}) {
      @{$frag_hits{$qname}{$hname}} = _greedy_filter(@{$frag_hits{$qname}{$hname}});
#      print scalar @{$frag_hits{$qname}{$hname}},"\n";
      my $sum_score = 0;
      foreach my $fp (@{$frag_hits{$qname}{$hname}}) {
#	print $fp->seqname," ",$fp->start," ",$fp->end," ",$fp->strand,," ",$fp->hseqname," ",$fp->hstart," ",$fp->hend," ",$fp->hstrand," ",$fp->score,"\n";
	$sum_score += $fp->score;
	if (! defined $highest_hname) {
	  $highest_hname = $hname;
	  $highest_score = $sum_score;
	} elsif ($sum_score > $highest_score) {
	  $highest_hname = $hname;
	  $highest_score = $sum_score;
	}
      }
    }
    
    print STDERR "$qname\t$highest_hname\t$highest_score\n";
#    next;
    my ($chr_name,$chr_start,$chr_end) = split /\./, $qname;
    
    my $sth = $db->prepare("select c.id,c.internal_id,s.chr_name,s.chr_start,s.chr_end,s.raw_start,s.raw_end,s.raw_ori from static_golden_path s,contig c where s.raw_id=c.internal_id and s.chr_name=\"$chr_name\" and (($chr_start>=s.chr_start && $chr_start<=s.chr_end) or ($chr_end>=s.chr_start and $chr_end<=s.chr_end) or (s.chr_start>$chr_start and s.chr_end<$chr_end))");
    # if type condition has to be added, take this query
    #  my $sth = $db->prepare("select c.id,c.internal_id,s.chr_name,s.chr_start,s.chr_end,s.raw_start,s.raw_end,s.raw_ori from static_golden_path s,contig c where s.raw_id=c.internal_id and s.chr_name=\"$chr_name\" and (($chr_start>=s.chr_start && $chr_start<=s.chr_end) or ($chr_end>=s.chr_start and $chr_end<=s.chr_end) or (s.chr_start>$chr_start and s.chr_end<$chr_end)) and type=\"$qy_static_type\"");
    
    unless ($sth->execute()) {
      $db->throw("Failed execution of a select query");
    }
    
    while (my ($id,$internal_id,$chr_name,$chr_start,$chr_end,$raw_start,$raw_end,$raw_ori) = $sth->fetchrow_array()) {
      #Homo_sapiens:AC062026.2.140587.164530::Mus_musculus:c078004285.Contig1
      print "Homo_sapiens:".$highest_hname."::Mus_musculus:".$id."\n";
    }
  }
}




=head2 _greedy_filter

    Title   :   _greedy_filter
    Usage   :   _greedy_filter(@)
    Function:   Clean the Array of Bio::EnsEMBL::FeaturePairs in three steps, 
                First, determines the highest scored hit, and fix the expected strand hit
                Second, hits on expected strand are kept if they do not overlap, 
                either on query or subject sequence, previous strored, higher scored hits.
                If hit goes trough the second step, the third test makes sure that the hit
                is coherent position according to previous ones. 
    Returns :   Array of Bio::EnsEMBL::FeaturePairs
    Args    :   Array of Bio::EnsEMBL::FeaturePairs

=cut

sub _greedy_filter {
  my (@features) = @_;

  @features = sort {$b->score <=> $a->score} @features;

  my @features_filtered;
  my $ref_strand;
  foreach my $fp (@features) {
    if (! scalar @features_filtered) {
        push @features_filtered, $fp;
	$ref_strand = $fp->hstrand;
        next;
    }
    next if ($fp->hstrand != $ref_strand);
    my $add_fp = 1;
    foreach my $feature_filtered (@features_filtered) {
      my ($start,$end,$hstart,$hend) = ($feature_filtered->start,$feature_filtered->end,$feature_filtered->hstart,$feature_filtered->hend);
      if (($fp->start >= $start && $fp->start <= $end) ||
	  ($fp->end >= $start && $fp->end <= $end) ||
	  ($fp->hstart >= $hstart && $fp->hstart <= $hend) ||
	  ($fp->hend >= $hstart && $fp->hend <= $hend)) {
	$add_fp = 0;
	last;
      }
      if ($ref_strand == 1) {
	unless (($fp->start > $end && $fp->hstart > $hend) ||
		($fp->end < $start && $fp->hend < $hend)) {
	  $add_fp = 0;
	  last
	}
      } elsif ($ref_strand == -1) {
	unless (($fp->start > $end && $fp->hstart < $hend) ||
		($fp->end < $start && $fp->hend > $hend)) {
	  $add_fp = 0;
	  last
	}
      }
    }
    push @features_filtered, $fp if ($add_fp);
  }

  return @features_filtered;
}
