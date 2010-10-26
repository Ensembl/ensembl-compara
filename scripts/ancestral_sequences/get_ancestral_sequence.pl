#!/usr/bin/env perl
use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Feature;
my $registry = "Bio::EnsEMBL::Registry";

$registry->load_registry_from_url('mysql://ensro@ens-livemirror');

my $species_name = "Homo sapiens";

my $species_assembly = $registry->get_adaptor($species_name, "core", "CoordSystem")->fetch_all->[0]->version();

my $slice_adaptor = $registry->get_adaptor($species_name, "core", "Slice");

my $method_link_species_set_adaptor = $registry->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");

my $genomic_align_tree_adaptor = $registry->get_adaptor("Multi", "compara", "GenomicAlignTree");

my $mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name("EPO", "primates");

my $compara_dbc = $registry->get_DBAdaptor("Multi", "compara")->dbc;

print_header($species_name, $species_assembly, $compara_dbc, $mlss);
exit;

my $slices = $slice_adaptor->fetch_all("toplevel", undef, 0, 1);
my $step = 10000000;

foreach my $slice (@$slices) {
  next unless (!$ARGV[0] or $slice->seq_region_name eq $ARGV[0] or
      $slice->coord_system_name eq $ARGV[0]);
  my $length = $slice->length;
  open(FASTA, ">human_ancestor_".$slice->seq_region_name.".fa") or die;
  print FASTA ">ANCESTOR_for_", $slice->name, "\n";
  open(BED, ">human_ancestor_".$slice->seq_region_name.".bed") or die;
  my $num_of_blocks = 0;
  for (my $start = 1; $start <= $length; $start += $step) {
    my $end = $start + $step - 1;
    if ($end > $length) {
      $end = $length;
    }
    my $sub_slice = $slice->sub_Slice($start, $end);
    $num_of_blocks += dump_ancestral_sequence($sub_slice, $mlss);
  }
  close(FASTA);
  close(BED);
  if ($num_of_blocks == 0) {
    unlink("human_ancestor_".$slice->seq_region_name.".bed", "human_ancestor_".$slice->seq_region_name.".fa");
  }
}

sub dump_ancestral_sequence {
  my ($slice, $mlss) = @_;
  my $num_of_blocks = 0;

  # Fill in the ancestral sequence with dots ('.') - default character
  my $sequence_length = $slice->length;
  my $sequence = "." x $sequence_length;

  # Get all the GenomicAlignTrees
  my $genomic_align_trees = $genomic_align_tree_adaptor->
      fetch_all_by_MethodLinkSpeciesSet_Slice(
          $mlss, $slice, undef, undef, "restrict");
  # Parse the GenomicAlignTree (sorted by their location on the query_genome
  foreach my $this_genomic_align_tree (sort {
#       scalar(@{$b->get_all_nodes}) <=> scalar(@{$a->get_all_nodes}) ||
      $a->reference_slice_start <=> $b->reference_slice_start ||
      $a->reference_slice_end <=> $b->reference_slice_end}
      @$genomic_align_trees) {
    my $ref_gat = $this_genomic_align_tree->reference_genomic_align_node;
    next if (!$ref_gat); # This should not happen as we get the GAT using a query Slice
    my $ref_aligned_sequence = $ref_gat->aligned_sequence;
    my $ancestral_sequence = $ref_gat->parent->aligned_sequence;
    my $sister_sequence;
    foreach my $child (@{$ref_gat->parent->children}) {
      if ($child ne $ref_gat) {
        $sister_sequence = $child->aligned_sequence;
      }
    }
    my $older_sequence;
    if ($ref_gat->parent->parent) {
      $older_sequence = $ref_gat->parent->parent->aligned_sequence;
    }
#    print $ref_aligned_sequence, "\n\n", "$ancestral_sequence\n\n\n\n";
    my $ref_ga = $ref_gat->genomic_align_group->get_all_GenomicAligns->[0];
    my $tree = $this_genomic_align_tree->newick_simple_format;
    $tree =~ s/\:[\d\.]+//g;
    $tree =~ s/_\w+//g;
    $tree =~ s/\[[\+\-]\]//g;
    print BED join("\t", $ref_ga->dnafrag->name, $ref_ga->dnafrag_start,
        $ref_ga->dnafrag_end, $tree), "\n";
    $num_of_blocks++;

    # Fix alignments, i.e., project them on the ref (human)
    my @segments = grep {$_} split(/(\-+)/, $ref_aligned_sequence);
    my $pos = 0;
    foreach my $this_segment (@segments) {
      my $length = length($this_segment);
      if ($this_segment =~ /\-/) {
        substr($ref_aligned_sequence, $pos, $length, "");
        substr($ancestral_sequence, $pos, $length, "");
        substr($sister_sequence, $pos, $length, "");
        substr($older_sequence, $pos, $length, "") if ($older_sequence);
      } else {
        $pos += $length;
      }
    }

    my $ref_start0 = $this_genomic_align_tree->reference_slice_start - 1;
    for (my $i = 0; $i < length($ancestral_sequence); $i++) {
      my $current_seq = substr($sequence, $i + $ref_start0, 1);
      next if ($current_seq ne "." and !$older_sequence);
      my $ancestral_seq = substr($ancestral_sequence, $i, 1);
      my $sister_seq = substr($sister_sequence, $i, 1);

      # Score the consensus. A lower score means a better consensus
      my $score = 0;
      if (!$older_sequence or substr($older_sequence, $i, 1) ne $ancestral_seq) {
        $score++;
      }
      if ($sister_seq ne $ancestral_seq) {
        $score++;
      }
      # Change the ancestral allele according to the score:
      # - score == 0 -> do nothing (uppercase)
      # - score == 1 -> change to lowercase
      # - score > 1 -> change to N
      if ($score == 1) {
        $ancestral_seq = lc($ancestral_seq);
      } elsif ($score > 1) {
        $ancestral_seq = "N";
      }

      ## Alignment overlaps
      # - $current_seq eq "." -> no overlap, sets the ancestral allele
      # - $current_seq and $ancestral_seq differ in case only -> use lowercase
      # - $current_seq and $ancestral_seq are different -> change to N
      if ($current_seq eq ".") { # no previous sequence
        substr($sequence, $i + $ref_start0, 1, $ancestral_seq);
      } elsif ($current_seq ne $ancestral_seq) { # overlap, diff allele
        if (lc($current_seq) eq lc($ancestral_seq)) {
          substr($sequence, $i + $ref_start0, 1, lc($ancestral_seq));
        } else {
          substr($sequence, $i + $ref_start0, 1, "N");
        }
      }
    }
    ## Free memory
    deep_clean($this_genomic_align_tree);
    $this_genomic_align_tree->release_tree();
  }
#     print FASTA $sequence, "\n";
  $sequence =~ s/(.{100})/$1\n/g;
  $sequence =~ s/\n$//;
  print FASTA $sequence, "\n";

  return $num_of_blocks;
}

sub deep_clean {
  my ($genomic_align_tree) = @_;

  my $all_nodes = $genomic_align_tree->get_all_nodes;
  foreach my $this_genomic_align_node (@$all_nodes) {
    my $this_genomic_align_group = $this_genomic_align_node->genomic_align_group;
    next if (!$this_genomic_align_group);
    foreach my $this_genomic_align (@{$this_genomic_align_group->get_all_GenomicAligns}) {
      foreach my $key (keys %$this_genomic_align) {
        if ($key eq "genomic_align_block") {
          foreach my $this_ga (@{$this_genomic_align->{$key}->get_all_GenomicAligns}) {
              my $gab = $this_ga->{genomic_align_block};
              next if (!$gab);
              my $gas = $gab->{genomic_align_array};

              for (my $i = 0; $gas and $i < @$gas; $i++) {
                  delete($gas->[$i]);
              }

              delete($this_ga->{genomic_align_block}->{genomic_align_array});
              delete($this_ga->{genomic_align_block}->{reference_genomic_align});
            undef($this_ga);
          }
        }
        delete($this_genomic_align->{$key});
      }
      undef($this_genomic_align);
    }
    undef($this_genomic_align_group);
  }
}

sub print_header {
  my ($species_name, $species_assembly, $compara_dbc, $mlss) = @_;

  my $database = $compara_dbc->dbname . '@' . $compara_dbc->host . ':' . $compara_dbc->port;
  my $mlss_name = $mlss->name . " (" . $mlss->dbID . ")";

  open(README, ">README") or die "Cannot open README file\n";
  print README qq"This directory contains the ancestral sequences for $species_name ($species_assembly).

The data have been extracted from the following alignment set:
# Database: $database
# MethodLinkSpeciesSet: $mlss_name

In the EPO (Enredo-Pecan-Ortheus) pipeline, Ortheus infers ancestral states
from the Pecan alignments. The confidence in the ancestral call is determined
by comparing the call to the ancestor of the ancestral sequence as well as
the 'sister' sequence of the query species. For instance, using a human-chimp-
macaque alignment to get the ancestral state of human, the human-chimp ancestor
sequence is compared to the chimp and to the human-chimp-macaque ancestor. A
high-confidence call is made whn all three sequences agree. If the ancestral
sequence agrees with one of the other two sequences only, we tag the call as
a low-confidence call. If there is more disagreement, the call is not made.

The convention for the sequence is:
ACTG : high-confidence call, ancestral state supproted by the other two sequences
actg : low-confindence call, ancestral state supported by one sequence only
N    : failure, the ancestral state is not supported by any other sequence
-    : the extant species contains an insertion at this postion
.    : no coverage in the alignment

You should find a summary.txt file, which contains statistics about the quality
of the calls.
";
  close(README);
}