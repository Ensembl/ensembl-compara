#!/usr/local/bin/perl -w

BEGIN {
    require "Bio/EnsEMBL/Compara/ComparaConf.pl";
    # Can we have a way of reading a (local) ComparaConf.pl as well?
    # e.g. if it exists in the current dir, use that one in preference
}

use strict;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::FeatureFactory;
use Bio::SeqIO;
use Getopt::Long;

$| = 1;

my %conf =  %::ComparaConf;

my $sb_species = $conf{'sb_species'};
my $sb_fragment_type = $conf{'sb_fragment_type'};
my $sb_fragment_size = $conf{'sb_fragment_size'};
my $qy_species = $conf{'qy_species'};
my $qy_host = $conf{'qy_host'};
my $qy_dbname = $conf{'qy_dbname'};
my $qy_dbuser = $conf{'qy_dbuser'};
my $qy_static_type = $conf{'qy_static_type'};
my $qy_chr_name_restriction = $conf{'qy_chr_name_restriction'};
my $qy_fragment_type = $conf{'qy_fragment_type'};
my %qy_chr_length;

my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $qy_host,
					     -user => $qy_dbuser,
					     -dbname => $qy_dbname);

my $sth = $db->prepare("select max(chr_end-chr_start) from static_golden_path where type=? and chr_name not like ?");

my $max_contig_length;

unless ($sth->execute($qy_static_type,$qy_chr_name_restriction)) {
  $db->throw("Failed execution of a select query");
} else {
  ($max_contig_length) = $sth->fetchrow_array();  
}

while (defined (my $exonerate_output_file = shift @ARGV)) {
  my %frag_hits;
  open F, $exonerate_output_file || die "Could not open $exonerate_output_file; $!.\n";
  print STDERR "$exonerate_output_file open...\n";
  my ($qy_frag_id,$tg_contig_id,$score);
  while (defined (my $line = <F>)) {
    chomp $line;
    #cigar: 11.958792.959291 290 500 - AC007006.3.1.112027 108878 109088 + 996.00 M 210
    if ($line =~ /^cigar:\s+(\S+)\s+(\d+)\s+(\d+)\s+([+-])\s+(\S+)\s+(\d+)\s+(\d+)\s+([+-])\s+(\d+\.\d+)\s+.*$/) {
      my ($qname,$qstart,$qend,$qstrand,$hname,$hstart,$hend,$hstrand,$score) = ($1,$2,$3,$4,$5,$6,$7,$8,$9);

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
    my ($chr_name,$chr_start,$chr_end) = split /\./, $qname;

    if ($qy_fragment_type eq "raw") { 
      my $sth = $db->prepare("select c.id,c.internal_id,s.chr_name,s.chr_start,s.chr_end,s.raw_start,s.raw_end,s.raw_ori from static_golden_path s,contig c where s.raw_id=c.internal_id and s.chr_name=? and s.chr_end>=? and s.chr_start>=? - ? + 1 and s.chr_start<=? and s.type=?");
      
      unless ($sth->execute($chr_name,$chr_start,$chr_start,$max_contig_length,$chr_end,$qy_static_type)) {
	$db->throw("Failed execution of a select query");
      }
      
      while (my ($id,$internal_id,$chr_name,$chr_start,$chr_end,$raw_start,$raw_end,$raw_ori) = $sth->fetchrow_array()) {
	#Homo_sapiens:raw:AC062026.2.140587.164530::Mus_musculus:raw:c078004285.Contig1
	print "$sb_species:$sb_fragment_type:$highest_hname"."::"."$qy_species:$qy_fragment_type:$id\n";
      }
    } elsif ($qy_fragment_type eq "vc") {

      unless ($qy_chr_length{$chr_name}) {
	my $sth = $db->prepare("select max(chr_end) from static_golden_path where chr_name=? and type=?");
	
	unless ($sth->execute($chr_name,$qy_static_type)) {
	  $db->throw("Failed execution of a select query");
	}

	$qy_chr_length{$chr_name} = $sth->fetchrow_array();
      }

      for (my $start = $sb_fragment_size * int($chr_start/$sb_fragment_size) + 1;$start <= $chr_end;$start += $sb_fragment_size) {
	my $end = $start + $sb_fragment_size - 1;
	$end = $qy_chr_length{$chr_name} if ($end > $qy_chr_length{$chr_name});
	my $id = $chr_name.".".$start.".".$end;
	print "$sb_species:$sb_fragment_type:$highest_hname"."::"."$qy_species:$qy_fragment_type:$id\n";
      }
    }
  }
}


## Taken from CrossComparer slightly modified

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
