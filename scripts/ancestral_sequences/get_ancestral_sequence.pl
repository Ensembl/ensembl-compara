#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

=head1 NAME

get_ancestral_sequence.pl

=head1 AUTHORS

 Javier Herrero

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script reads an EPO alignment and prints the ancestral sequence predicted
for the ancestor just older than the query species. By default, we use the
primates alignment, and the query is human, thus giving the sequence of the
human/chimp ancestor.
The script creates a directory with a pair of BED+FASTA files for each
chromosome of the query species. The FASTA file contains the actual sequence,
while the BED file contains the phylogenetic tree associated with each region.

=head1 SYNOPSIS

perl get_ancestral_sequence.pl --help

perl get_ancestral_sequence.pl
    [--url main_ensembl_url]
    [--conf|--registry registry_file]
    [--compara_url url_of_compara_database]
    [--species name_of_query_species]
    [--alignment_set name_of_species_set]
    [--mlss_id mlss_id]
    [--dir directory_name]

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--url main_ensembl_url]>

URL of Ensembl databases, e.g. mysql://anonymous@ensembldb.ensembl.org/

=item B<[--conf|--registry registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<[--compara_url url_of_compara_database]>

The compara database that contains the EPO alignment. If none given,
the script will try to connect to the "Multi" database

=back

=head2 INPUT ALIGNMENT CONFIGURATION

=over

=item B<[--mlss_id mlss_id]>

The MethodLinkSpeciesSet ID of the alignment. By default, the script will
try to fetch the alignment associated with a species set correctly named
(see L<--alignment_set>). It then tries all the EPO alignments found with
a matching MLSS name

=item B<[--species name_of_query_species]>

The name for the species to get the ancestral sequence of (default: "Homo sapiens")

=item B<[--alignment_set name_of_query_species]>

The name of the species set of the alignment (default: "primates")

=back

=head2 OUTPUT CONFIGURATION

=over

=item B<[--dir directory_name]>

Where to dump all the files. Defaults to "${species_production_name}_ancestor_${species_assembly}_e${ensembl_version}"

=back

=head2 Examples

perl $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/ancestral_sequences/get_ancestral_sequence.pl --conf $ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_conf.pl --compara_url mysql://ensro@compara5/sf5_epo_8primates_77 --species homo_sapiens

=head1 INTERNAL METHODS

=cut


use Bio::EnsEMBL::Registry;
use Getopt::Long;

my $reg = "Bio::EnsEMBL::Registry";

my $help;
my $registry_file;
my $url;
my $compara_url;
my $species_name = "Homo sapiens";
my $alignment_set = "primates";
my $mlss_id;
my $dir = '';

GetOptions(
  "help" => \$help,
  "url=s" => \$url,
  "compara_url=s" => \$compara_url,
  "conf|registry=s" => \$registry_file,
  "species=s" => \$species_name,
  "alignment_set=s" => \$alignment_set,
  "mlss_id=i" => \$mlss_id,
  "dir=s" => \$dir,
);

# Print Help and exit if help is requested
if ($help) {
  exec("/usr/bin/env perldoc $0");
}

if ($registry_file) {
  die "Registry file '$registry_file' doesn't exist\n" if (!-e $registry_file);
  $reg->load_all($registry_file, 1);
} elsif ($url) {
  $reg->load_registry_from_url($url, 1);
} else {
  $reg->load_all();
}

my $compara_dba;
if ($compara_url) {
  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
  $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara_url);
} else {
  $compara_dba = $reg->get_DBAdaptor("Multi", "compara");
}

# Check that the "ancestral_sequences" species is available
if (not $reg->get_DBAdaptor('ancestral_sequences', 'core')) {
  if ($reg->get_DBAdaptor('ancestral_curr', 'core')) {
    # 'ancestral_curr' is the name of the database in the production_reg_conf.pl
    $reg->add_alias('ancestral_curr', 'ancestral_sequences');
  }
}

my $species_scientific_name = $reg->get_adaptor($species_name, "core", "MetaContainer")->get_scientific_name();
my $species_production_name = $reg->get_adaptor($species_name, "core", "MetaContainer")->get_production_name();
my $species_assembly = $reg->get_adaptor($species_name, "core", "CoordSystem")->fetch_all->[0]->version();
my $ensembl_version = $reg->get_adaptor($species_name, "core", "MetaContainer")->list_value_by_key('schema_version')->[0];

if (!$dir) {
  $dir = "${species_production_name}_ancestor_${species_assembly}_e${ensembl_version}";
}

system("mkdir -p $dir");

my $slice_adaptor = $reg->get_adaptor($species_name, "core", "Slice");

my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

my $genomic_align_tree_adaptor = $compara_dba->get_GenomicAlignTreeAdaptor;

my $mlss;
if ($mlss_id) {
  $mlss = $method_link_species_set_adaptor->fetch_by_dbID($mlss_id);
} else {
  $mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name("EPO", $alignment_set);
}
if (!$mlss) {
  my $all_mlss = $method_link_species_set_adaptor->fetch_all_by_method_link_type('EPO');
  my @good_mlss = grep {$_->name =~ /$alignment_set/i} @$all_mlss;
  $mlss = $good_mlss[0] if @good_mlss;
}
die "Couldn't find a MLSS for the EPO $alignment_set alignment\n" unless $mlss;
warn sprintf("Found MLSS mlss_id=%d name='%s'\n", $mlss->dbID, $mlss->name);

my $compara_dbc = $compara_dba->dbc;

print_header($species_scientific_name, $species_assembly, $compara_dbc, $mlss);

my $slices = $slice_adaptor->fetch_all("toplevel", undef, 0, 1);
my $step = 10000000;

foreach my $slice (@$slices) {
  next unless (!$ARGV[0] or $slice->seq_region_name eq $ARGV[0] or
      $slice->coord_system_name eq $ARGV[0]);
  my $length = $slice->length;
  open(FASTA, ">$dir/${species_production_name}_ancestor_".$slice->seq_region_name.".fa") or die;
  print FASTA ">ANCESTOR_for_", $slice->name, "\n";
  open(BED, ">$dir/${species_production_name}_ancestor_".$slice->seq_region_name.".bed") or die;
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
    unlink("${species_production_name}_ancestor_".$slice->seq_region_name.".bed",
        "${species_production_name}_ancestor_".$slice->seq_region_name.".fa");
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
    my $tree = $this_genomic_align_tree->newick_format("simple");
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
          next if (!$this_genomic_align->{$key});
          foreach my $this_ga (@{$this_genomic_align->{$key}->get_all_genomic_aligns_for_node}) {
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

  open(README, ">$dir/README") or die "Cannot open README file\n";
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
actg : low-confidence call, ancestral state supported by one sequence only
N    : failure, the ancestral state is not supported by any other sequence
-    : the extant species contains an insertion at this postion
.    : no coverage in the alignment

You should find a summary.txt file, which contains statistics about the quality
of the calls.
";
  close(README);
}
