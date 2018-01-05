#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use strict;
use warnings;
use Bio::EnsEMBL::Registry;
use Bio::AlignIO;

use Getopt::Long;

my ($binaryfile,$debug);
$binaryfile = '/software/pubseq/bin/scorecons';
GetOptions(
	   'i|binary|binaryfile:s' => \$binaryfile,
           'd|debug:s' => \$debug,
          );
my $self = bless {};

Bio::EnsEMBL::Registry->load_registry_from_db(-host=>"ensembldb.ensembl.org", -user=>"anonymous");

my $human_gene_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Homo sapiens", "core", "Gene");
my $gene_member_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "GeneMember");
my $gene_tree_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "GeneTree");

my $genes = $human_gene_adaptor->fetch_all_by_external_name('BRCA2');

foreach my $gene (@$genes) {
  my $member = $gene_member_adaptor->fetch_by_stable_id($gene->stable_id);
  die "no members" unless (defined $member);
  # Fetch the gene tree
  my $tree =  $gene_tree_adaptor->fetch_default_for_Member($member);
  die "no tree" unless (defined $tree);
  my @leaves = @{$tree->get_all_leaves};
  my $member_domain;
  my $domain_boundaries;
  my $domain_coverage;
  my $representative_member = '';
  while (my $member = shift @leaves) {
    my $seq_member_id = $member->dbID;
    my $member_stable_id = $member->stable_id;
    print STDERR "[$member_stable_id]\n";
    unless ($representative_member ne '') {
      if ($member_stable_id =~ /ENSP0/) { 
        my $d = $member->description; $d =~ /Gene\:(\S+)/; my $g = $1; $representative_member = $g;
      } elsif ($member_stable_id =~ /ENSMUSP0/) { 
        my $d = $member->description; $d =~ /Gene\:(\S+)/; my $g = $1; $representative_member = $g;
      } elsif ($member_stable_id =~ /ENSDARP0/) { 
        my $d = $member->description; $d =~ /Gene\:(\S+)/; my $g = $1; $representative_member = $g;
      }
    }
    my $translation;
    eval { $translation = $member->get_Translation;};
    if ($@ || !defined($translation)) {
      my $dba = Bio::EnsEMBL::Registry->get_DBAdaptor($member->genome_db->name, "core");
      next if (!defined $dba);
      $member->genome_db->db_adaptor($dba);
      $translation = $member->get_Translation;
      next if (!defined $translation);
    }
    my @domains = @{$translation->get_all_ProteinFeatures('pfam')};
    my $count = 1;
    my $member_domain_counter;
    while (my $domain = shift @domains) {
      my $type = $domain->analysis->logic_name;
      next unless ($type =~ /Pfam/i);
      my $start = $domain->start;
      my $end = $domain->end;
      my $pfamid = $domain->hseqname;
      # We first add up a $member_domain->{$pfamid}{$seq_member_id}
      $member_domain_counter->{$pfamid}++;
      # Then we get it to start on the right index
      my $copy = $member_domain_counter->{$pfamid};
      $member_domain->{$pfamid}{$seq_member_id}{$copy}{start} = $start;
      $member_domain->{$pfamid}{$seq_member_id}{$copy}{end} = $end;
      $member_domain->{$pfamid}{$seq_member_id}{$copy}{id} = $member->stable_id;
      $count++;

    }
  }
  unless (defined($member_domain)) {
    $tree->add_tag('pfam_representative_member',$representative_member) unless ($self->{debug});
    $tree->add_tag('pfam_num_domains',0) unless ($self->{debug});
    $tree->add_tag('pfam_non_overlapping_domains',0) unless ($self->{debug});
    $tree->add_tag('pfam_domain_coverage',0) unless ($self->{debug});
    $tree->add_tag('pfam_domain_string','na') unless ($self->{debug});
    $tree->add_tag('pfam_domain_vector_string','na') unless ($self->{debug});
    next;
  }

  my $aln_domains_hash;

  my $aln = $tree->get_SimpleAlign(-id_type => 'MEMBER');
  my $prev_aln_length = $tree->get_value_for_tag("aln_length");
  if ($prev_aln_length eq '') {
    my $aln_length = $aln->length; $tree->add_tag('aln_length',$aln_length);
  }
  my $ranges;
  foreach my $pfamid (keys %$member_domain) {
    my $aln_domain_range = Bio::EnsEMBL::Mapper::RangeRegistry->new();
    $ranges->{$pfamid} = $aln_domain_range;
    foreach my $seq_member_id (keys %{$member_domain->{$pfamid}}) {
      foreach my $copy (keys %{$member_domain->{$pfamid}{$seq_member_id}}) {
        my $start = $member_domain->{$pfamid}{$seq_member_id}{$copy}{start};
        my $end = $member_domain->{$pfamid}{$seq_member_id}{$copy}{end};
        my $start_loc = $aln->column_from_residue_number($seq_member_id, $start);
        my $end_loc   = $aln->column_from_residue_number($seq_member_id, $end);
        $domain_boundaries->{$pfamid}{aln_start}{$start_loc}++;
        $domain_boundaries->{$pfamid}{aln_end}{$end_loc}++;
        $domain_boundaries->{$pfamid}{aln_start_id}{$start_loc}{$member_domain->{$pfamid}{$seq_member_id}{$copy}{id}} = 1;
        $domain_boundaries->{$pfamid}{aln_end_id}{$start_loc}{$member_domain->{$pfamid}{$seq_member_id}{$copy}{id}} = 1;
        $member_domain->{$pfamid}{$seq_member_id}{$copy}{aln_start}{$start_loc}++;
        $member_domain->{$pfamid}{$seq_member_id}{$copy}{aln_end}{$end_loc}++;
        my $coord_pair = $start_loc . "_" . $end_loc;
        $aln_domains_hash->{$coord_pair} = 1;
        $aln_domain_range->check_and_register( $pfamid, $start_loc, $end_loc, undef, undef, 1);
      }
    }
  }
  my $num_elements = scalar keys %$aln_domains_hash;
  print STDERR "num_elements $num_elements\n";

  my $ranged_coverage;
  my $global_domain_range = Bio::EnsEMBL::Mapper::RangeRegistry->new();
  foreach my $pfamid (keys %$ranges) {

    my $aln_domain_range = $ranges->{$pfamid};
    foreach my $range (@{$aln_domain_range->get_ranges($pfamid)}) {
      my ($start_range_loc,$end_range_loc) = @$range;
      my $range_id = $start_range_loc . "_" . $end_range_loc;
      my ($range_starts,$range_ends);

      # Calculating start
      foreach my $start (keys %{$domain_boundaries->{$pfamid}{aln_start}}) {
        next unless ($start >= $start_range_loc && $start <= $end_range_loc);
        $range_starts->{$start} = $domain_boundaries->{$pfamid}{aln_start}{$start};
      }
      my $max_num_start = 0; my $consensus_start;
      foreach my $start (sort {$a<=>$b} keys %{$range_starts}) {
        my $num = $range_starts->{$start};
        if ($max_num_start < $num) {
          $max_num_start = $num; $consensus_start = $start;
        }
        if (($max_num_start == $num) && ($consensus_start < $start)) {
          $max_num_start = $num; $consensus_start = $start;
        }
      }
      # Calculating end
      foreach my $end (keys %{$domain_boundaries->{$pfamid}{aln_end}}) {
        next unless ($end >= $start_range_loc && $end <= $end_range_loc);
        $range_ends->{$end} = $domain_boundaries->{$pfamid}{aln_end}{$end};
      }
      my $max_num_end = 0; my $consensus_end;
      foreach my $end (sort {$a<=>$b} keys %{$range_ends}) {
        my $num = $range_ends->{$end};
        if (($max_num_end < $num)  && ($end > $consensus_start)) {
          $max_num_end = $num; $consensus_end = $end;
        }
        if (($max_num_end == $num) && ($consensus_end > $end) && ($end > $consensus_start)) {
          $max_num_end = $num; $consensus_end = $end;
        }
      }

      $ranged_coverage->{$pfamid}{$range_id}{consensus_start} = $consensus_start;
      $ranged_coverage->{$pfamid}{$range_id}{consensus_end} = $consensus_end;
      #if ($consensus_end < $consensus_start) {
        #$DB::single=1;1;
      #}
      $global_domain_range->check_and_register( 'global', $consensus_start, $consensus_end, undef, undef, 1);
      $ranged_coverage->{$pfamid}{$range_id}{consensus_length} = $consensus_end - $consensus_start;
    }
  }

  my $pfam_num_domains = 0;
  my $root_id = $tree->root_id;
  my $pfam_domain_string = join(":",sort keys %$ranged_coverage);
  my $pfam_domain_coverage;
  my $pfam_non_overlapping_domains = 0; my $in = 0; my $out = 1;
  my @domain_vector;
  my @range_vector;
  foreach my $range (@{$global_domain_range->get_ranges('global')}) {
    my ($start_range_loc,$end_range_loc) = @$range;
    my $length = $end_range_loc - $start_range_loc;
    $pfam_domain_coverage += $length;
    push @range_vector, "$start_range_loc:$end_range_loc";
  }
  foreach my $pfamid (sort keys %$ranged_coverage) {
    $pfam_num_domains++;
    foreach my $range_id (keys %{$ranged_coverage->{$pfamid}}) {
      push @domain_vector, $pfamid;
      $pfam_non_overlapping_domains++;
    }
  }
  my $range_vector = join(";",@range_vector);
  my $pfam_domain_vector_string = join(":",@domain_vector);
$tree->add_tag('pfam_representative_member',$representative_member);
  print 'pfam_representative_member ',$representative_member, "\n" if ($self->{debug});
$tree->add_tag('pfam_num_domains',$pfam_num_domains);
  print 'pfam_num_domains ',$pfam_num_domains, "\n" if ($self->{debug});
$tree->add_tag('pfam_non_overlapping_domains',$pfam_non_overlapping_domains);
  print 'pfam_non_overlapping_domains ',$pfam_non_overlapping_domains, "\n" if ($self->{debug});
$tree->add_tag('pfam_domain_coverage',$pfam_domain_coverage);
  print 'pfam_domain_coverage ',$pfam_domain_coverage, "\n" if ($self->{debug});
$tree->add_tag('pfam_domain_string',$pfam_domain_string);
  print 'pfam_domain_string ',$pfam_domain_string, "\n" if ($self->{debug});
$tree->add_tag('pfam_domain_vector_string',$pfam_domain_vector_string);
  print 'pfam_domain_vector_string ',$pfam_domain_vector_string, "\n" if ($self->{debug});
$tree->add_tag('pfam_domain_range_vector_string',$range_vector);
  print 'pfam_domain_range_vector_string ',$range_vector, "\n" if ($self->{debug});
  print "\n";

  # Output alignment
  my $alnout = Bio::AlignIO->new
    (-file => '>aln.fasta',
     -format => 'fasta');
  $alnout->write_aln($tree->get_SimpleAlign);
  $alnout->close;
  # Run scorecons
  my $cmd = "$binaryfile aln.fasta --matrixnorm karlinlike --method valdar01 --dops div_pos.out > result.txt";
  print STDERR "Running (will take a while):\n # $cmd\n";
  unless(system("$cmd") == 0) {
    warn ("error return value for program, $!\n");
  }
  print STDERR "Finished.\n";
  open RES,"result.txt" or die $!;
  my $pos = 1;
  my $scores;
  while (<RES>) {
    my ($score,$hash,$aln) = split(" ",$_);
    $scores->{$pos} = $score; $pos++;
  }
  close RES;

  foreach my $i (0..((scalar @range_vector)-1)) {
    my ($start,$end) = split(":",$range_vector[$i]);
    print "[$i] $start:$end ", $domain_vector[$i], " scores \n";
    foreach my $j ($start .. $end) {
      print "aln_pos:$j, score:", $scores->{$j}, "\n";
    }
  }

  $tree->release_tree;
}
