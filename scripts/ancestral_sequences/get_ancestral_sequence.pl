#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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

Note that coordinates in the BED file are 1-based, so that an interval spanning
the full extent of a chromosome of length 1000 bp would have a start position of
1 in the chromStart column and an end position of 1000 in the chromEnd column.

=head1 SYNOPSIS

perl get_ancestral_sequence.pl --help

perl get_ancestral_sequence.pl
    [--alignment_db   url/registry alias for EPO alignments ]
    [--ancestral_db   url/registry alias for ancestral core ]
    [--reg_conf       registry config file                  ]
    [--species        name of query species                 ]
    [--target_species name of target species                ]
    [--alignment_set  name of species set                   ]
    [--mlss_id        mlss id                               ]
    [--dir            directory name for output             ]
    [--debug          run in debug mode                     ]
    [--step           query species slice step size         ]

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--alignment_db url_or_reg_alias_for_epo]>

URL of EPO database, e.g. mysql://anonymous@ensembldb.ensembl.org/
or registry_alias

=item B<[--ancestral_db url_or_reg_alias_for_ancestral_core]>

The core ancestral database. May be a URL or a registry alias

=item B<[--conf|--registry registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file

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

=item B<[--target_species name_of_target_species]>

The name of a target species whose most recent common ancestor
with the query species is taken as the ancestral sequence.

=item B<[--alignment_set name_of_query_species]>

The name of the species set of the alignment (default: "primates")

=back

=head2 OUTPUT CONFIGURATION

=over

=item B<[--dir directory_name]>

Where to dump all the files. Defaults to "${species_production_name}_ancestor_${species_assembly}"

=item B<[--debug]>

Run script in debug mode. Script halts after verification that all databases can be
seen. Extra verbose. No output files created.

=back

=head2 OTHER PARAMETERS

=over

=item B<[--step step_size]>

Slices of the query species top-level sequences are processed in intervals of step_size (default: 10,000,000 bases).

=back

=head2 Examples

perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/ancestral_sequences/get_ancestral_sequence.pl --conf $ENSEMBL_ROOT_DIR/ensembl-compara/conf/vertebrates/production_reg_conf.pl --compara_url mysql://ensro@compara5/sf5_epo_8primates_77 --species homo_sapiens

=head1 INTERNAL METHODS

=cut


use Data::Dumper;
use Getopt::Long;
use List::Util qw/min/;
use Pod::Usage;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw/throw/;
use Bio::EnsEMBL::Utils::IO qw/:spurt/;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

no warnings 'uninitialized';

my $reg = "Bio::EnsEMBL::Registry";

my $species_name = "homo_sapiens";
my $target_species_name;
my $alignment_set = "primates";
my $dir = '';
my $debug = 0;
my $max_files_per_dir = 500000;
my $genome_dumps_dir;
my ( $default_aln_alias, $default_anc_alias ) = ( 'Multi', 'ancestral_curr' );
my ( $help, $mlss_id, $alignment_db, $ancestral_db, $registry_file );
my $min_step = 10_000_000;
my $step = $min_step;

GetOptions(
  "help" => \$help,
  "alignment_db=s" => \$alignment_db,
  "ancestral_db=s" => \$ancestral_db,
  "conf|reg_conf=s" => \$registry_file,
  "species=s" => \$species_name,
  "target_species=s" => \$target_species_name,
  "alignment_set=s" => \$alignment_set,
  "mlss_id=i" => \$mlss_id,
  "dir=s" => \$dir,
  'genome_dumps_dir=s' => \$genome_dumps_dir,
  "debug" => \$debug,
  "step=i" => \$step,
) or pod2usage(-help => 1);


# Print Help and exit if help is requested
if ($help) {
  exec("/usr/bin/env perldoc $0");
}

my ( $aln_url, $anc_url, $aln_alias, $anc_alias, $compara_dba );

# check if alignment and ancestral dbs are URLs or registry aliases
if ( defined $alignment_db && $alignment_db =~ m/^mysql:\/\// ) { $aln_url = $alignment_db; }
else { $aln_alias = $alignment_db; }
if ( defined $ancestral_db && $ancestral_db =~ m/^mysql:\/\// ) { $anc_url = $ancestral_db; }
else { $anc_alias = $ancestral_db; }

print "aln_url: $aln_url\taln_alias : $aln_alias\nanc_url : $anc_url\tanc_alias : $anc_alias\n" if ( $debug );

# if only aliases are defined, a reg_conf is compulsory
die ( "ERROR: aliases detected ('$aln_alias' & '$anc_alias'), but no registry file was given" ) if ( (defined $aln_alias || defined $anc_alias) && ! defined $registry_file );

die ( "ERROR: step size $step is too small (min=$min_step)" ) unless ($step >= $min_step);

# load DBs passed as URLs
if ( defined $aln_url || defined $anc_url ) {
    if ( defined $aln_url ) {
        print "Using $aln_url as compara DBA\n" if ( $debug );
        $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$aln_url);

        # make sure locators are present in genome_db when no ancestral DB is specified
        if ( ! defined $anc_url ) {
            my $gdb_adaptor = $compara_dba->get_GenomeDBAdaptor();
            my $gdb         = $gdb_adaptor->fetch_by_name_assembly( $species_name );
            die ( "ERROR: $aln_url is missing genome_db locators for $species_name" ) unless ( $gdb->locator );
        }

    }
    if ( defined $anc_url ){
        $anc_url .= "?group=core&species=$species_name";
        print "Loading $anc_url into registry\n" if ( $debug );
        $reg->load_registry_from_url( $anc_url );
    }
}
elsif ( $registry_file ) {
    print ( "Loading $registry_file into registry\n" ) if ( $debug );
    $reg->load_all($registry_file, "verbose", 0, 0, "throw_if_missing");
    
    $anc_alias ||= $default_anc_alias;
    $aln_alias ||= $default_aln_alias;

    print "Using following aliases:\n\tancestral : $anc_alias\n\talignment : $aln_alias\n" if ( $debug );

    $compara_dba = $reg->get_DBAdaptor($aln_alias, "compara");
    if (!$reg->get_DBAdaptor($ancestral_db, 'core')) {
        throw("Cannot find '$ancestral_db' in the Registry");
    }
    if ($reg->alias_exists('ancestral_sequences')) {
        warn "Overriding the 'ancestral_sequences' Registry entry";
        $reg->remove_DBAdaptor('ancestral_sequences', 'core');
    }
    $reg->add_alias($anc_alias, 'ancestral_sequences');
    warn "Will connect to the ancestral database '$ancestral_db'\n";

} 
else {
    print "Loading live (ensembldb.ensembl.org) DB into registry\n" if ( $debug );
    $reg->load_registry_from_db(
      -host=>'ensembldb.ensembl.org',
      -user=>'anonymous',
    );
    $compara_dba = $reg->get_DBAdaptor( $default_aln_alias, 'compara' );
}

# We'll constantly be hitting the databases. Don't disconnect until the end
map {$_->db_adaptor->dbc->disconnect_when_inactive(0)} @{$compara_dba->get_GenomeDBAdaptor->fetch_all};
$compara_dba->get_GenomeDBAdaptor->dump_dir_location($genome_dumps_dir);

my $species_scientific_name = $reg->get_adaptor($species_name, "core", "MetaContainer")->get_scientific_name();
my $species_production_name = $reg->get_adaptor($species_name, "core", "MetaContainer")->get_production_name();
my $species_assembly = $reg->get_adaptor($species_name, "core", "CoordSystem")->fetch_all->[0]->version();
my $ensembl_version = $reg->get_adaptor($species_name, "core", "MetaContainer")->list_value_by_key('schema_version')->[0];



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

if ( $debug ) {
    print "\nRan in debug mode. No files created. Configuration appears good.\n\n";
    exit(0);
}

if (!$dir) {
    $dir = "${species_production_name}_ancestor_${species_assembly}";
}

system("mkdir -p $dir");

my $compara_dbc = $compara_dba->dbc;

print_header($species_scientific_name, $species_assembly, $compara_dbc, $mlss);

my $slices = $slice_adaptor->fetch_all("toplevel", undef, 0, 1);
my %karyo_slices = map {$_->seq_region_name => 1} @{ $slice_adaptor->fetch_all_karyotype };

# sometimes too many files for a single directory will be created
# partition the files into subdirs if this is the case
# my $partition_files = ( scalar @$slices >= $max_files_per_dir ) ? 1 : 0;

# We need to remove any previously written non-chromosomal
# files at the outset, to enable a cleaner rerun if needed.
my %non_karyo_coord_systems;
foreach my $slice (@$slices) {
    next if ($karyo_slices{$slice->seq_region_name});
    $non_karyo_coord_systems{$slice->coord_system_name} = 1;
}
foreach my $coord_system_name (keys %non_karyo_coord_systems) {
    foreach my $file_ext ('.bed', '.fa') {
        my $file_path = sprintf('%s/%s_ancestor_%s.%s', $dir, $species_production_name, $coord_system_name, $file_ext);
        unlink($file_path) if (-f $file_path);
    }
}

foreach my $slice (@$slices) {
  next unless (!$ARGV[0] or $slice->seq_region_name eq $ARGV[0] or
      $slice->coord_system_name eq $ARGV[0]);
  my $length = $slice->length;

  my $fasta_fh;
  my $bed_fh;
  if ( $karyo_slices{$slice->seq_region_name} ) { # one file per chr
      open($fasta_fh, '>', "$dir/${species_production_name}_ancestor_".$slice->seq_region_name.".fa") or die;
      open($bed_fh, '>', "$dir/${species_production_name}_ancestor_".$slice->seq_region_name.".bed") or die;
  } else { # one file per-coord_system for non-chromosomes
      open($fasta_fh, '>>', "$dir/${species_production_name}_ancestor_".$slice->coord_system_name.".fa") or die;
      open($bed_fh, '>>', "$dir/${species_production_name}_ancestor_".$slice->coord_system_name.".bed") or die;
  }

  print $fasta_fh ">ANCESTOR_for_", $slice->name, "\n";  
  my $num_of_blocks = 0;
  for (my $start = 1; $start <= $length; $start += $step) {
    my $end = $start + $step - 1;
    if ($end > $length) {
      $end = $length;
    }
    my $sub_slice = $slice->sub_Slice($start, $end);
    $num_of_blocks += dump_ancestral_sequence($fasta_fh, $bed_fh, $sub_slice, $mlss);
  }
  close($fasta_fh);
  close($bed_fh);
  if ($num_of_blocks == 0) {
    unlink("${species_production_name}_ancestor_".$slice->seq_region_name.".bed",
        "${species_production_name}_ancestor_".$slice->seq_region_name.".fa");
  }
}

sub dump_ancestral_sequence {
  my ($fasta_fh, $bed_fh, $slice, $mlss) = @_;
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

    my @ref_ancestors = @{$ref_gat->get_all_ancestors};

    my $anc_gat;
    my $ref_lineage_root;
    if ($target_species_name) {
      my @leaf_nodes = @{$this_genomic_align_tree->get_all_leaves};
      my @non_ref_nodes = grep { $_->node_id != $ref_gat->node_id } @leaf_nodes;
      my @target_nodes = grep { $_->get_genome_db_for_node->name eq $target_species_name } @non_ref_nodes;

      next if (!scalar(@target_nodes));

      my @ref_anc_nodes = @{$ref_gat->get_all_ancestors};
      my @ref_anc_idxs = (0 .. scalar(@ref_anc_nodes) - 1);

      my $mrca_idx = $ref_anc_idxs[-1];
      foreach my $target_node (@target_nodes) {
        my $shared_anc_node = $ref_gat->find_first_shared_ancestor($target_node);

        foreach my $ref_anc_idx (@ref_anc_idxs) {
          my $ref_anc_node = $ref_anc_nodes[$ref_anc_idx];
          if ($ref_anc_node->node_id == $shared_anc_node->node_id) {
            $mrca_idx = $ref_anc_idx if ($ref_anc_idx < $mrca_idx);
            last;
          }
        }
      }

      $anc_gat = $ref_anc_nodes[$mrca_idx];
      $ref_lineage_root = $mrca_idx > 0 ? $ref_anc_nodes[$mrca_idx-1] : $ref_gat;

    } else {
      $anc_gat = $ref_gat->parent;
      $ref_lineage_root = $ref_gat;
    }

    my $ancestral_sequence = $anc_gat->aligned_sequence;
    my $sister_sequence = $ref_lineage_root->siblings->[0]->aligned_sequence;
    my $older_sequence;
    if ($anc_gat->parent) {
      $older_sequence = $anc_gat->parent->aligned_sequence;
    }
#    print $ref_aligned_sequence, "\n\n", "$ancestral_sequence\n\n\n\n";
    my $ref_ga = $ref_gat->genomic_align_group->get_all_GenomicAligns->[0];

    foreach my $node (@{$this_genomic_align_tree->get_all_leaves}) {
      # Species-name prefix of subsitution regex adapted from:
      # https://github.com/Ensembl/ensembl-datacheck/blob/6b3d185/lib/Bio/EnsEMBL/DataCheck/Checks/MetaKeyFormat.pm#L59
      my $node_name = $node->name =~ s/^(_?[a-z0-9]+_[a-z0-9_]+)_.+?_\d+_\d+\[[-+]\]$/$1/r;
      $node->name($node_name);
    }

    my $tree = $this_genomic_align_tree->newick_format('ryo', '%{^-n|i}'); # simple, without branch lengths
    print $bed_fh join("\t", $ref_ga->dnafrag->name, $ref_ga->dnafrag_start,
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
  $sequence =~ s/(.{100})/$1\n/g;
  $sequence =~ s/\n$//;
  print $fasta_fh $sequence, "\n";

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

  spurt("$dir/README", qq"This directory contains the ancestral sequences for $species_name ($species_assembly).

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

The convention for the ancestral sequence region coordinates is 1-based,
so that in a chromosome of length 1000 bp, the first position would be 1
and the final position would be 1000.

You should find a summary.txt file, which contains statistics about the quality
of the calls.
");
}
