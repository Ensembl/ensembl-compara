#!/usr/local/ensembl/bin/perl -w

my $description = q{
###########################################################################
##
## PROGRAM DumpMultiAlign.pl
##
## AUTHORS
##    Abel Ureta-Vidal (abel@ebi.ac.uk)
##    Javier Herrero (jherrero@ebi.ac.uk)
##
## COPYRIGHT
##    This modules is part of the Ensembl project http://www.ensembl.org
##
## DESCRIPTION
##    This script dumps (pairwise or multiple) genomic alignments from
##    an EnsEMBL Compara Database.
##
###########################################################################

};

=head1 NAME

DumpMultiAlign.pl

=head1 AUTHORS

 Abel Ureta-Vidal (abel@ebi.ac.uk)
 Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

This modules is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script dumps (pairwise or multiple) genomic alignments from
an EnsEMBL Compara Database.

=head1 SYNOPSIS

perl DumpMultiAlign.pl --species human --seq_region 14 --seq_region_start 75000000
    --seq_region_end 75010000 --alignment_type BLASTZ_NET --set_of_species human:mouse

perl DumpMultiAlign.pl
    [--reg_conf registry_configuration_file]
    [--dbname compara_db_name]
    [--species species]
    [--coord_system coordinates_name]
    --seq_region region_name
    --seq_region_start start
    --seq_region_end end
    [--split_size 1000]
    [--alignment_type method_link_name]
    [--set_of_species species1:species2:species3:...]
    [--output_format clustalw|fasta|...]
    [--output_file filename]

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--db mysql://user[:passwd]@host[:port]]>

The script will auto-configure the Registry using the
databases in this MySQL instance. Default:
mysql://anonymous@ensembldb.ensembl.org

=item B<[--reg_conf registry_configuration_file]>

If you are using a non-standard setting, you can specify a
Bio::EnsEMBL::Registry configuration file to create the
appropriate connections to the databases.

=item B<[--dbname compara_db_name]>
  
the name of compara DB in the registry_configuration_file or any
of its aliases. Uses "compara" by default.

=back

=head2 SPECIFYING THE QUERY SLICE

=over

=item B<[--species species]>
  
Query species. Default is "human"

=item B<[--coord_system coordinates_name]>
  
By default this script dumps for one particular top-level seq_region.
This option allows to dump, for instance, all the alignments on all
the top-level supercontig in one go.

=item B<--seq_region region_name>
  
Query region name, i.e. the chromosome name

=item B<--seq_region_start start>

=item B<--seq_region_end end>

=back

=head2 SPECIFYING THE ALIGNMENT TYPE

=over

=item B<[--alignment_type method_link_name]>
  
The type of alignment. Default is "BLASTZ_NET"

=item B<[--set_of_species species1:species2:species3:...]>
  
The list of species used to get those alignments. Default is
"human:mouse". The names should correspond to the name of the
core database in the registry_configuration_file or any of its
aliases

=back

=head2 OUTPUT

=over

=item B<[--original_seq]>

Dumps orignal sequences instead of the aligned ones.

NB: This won't work properly with some file formats
like clustalw

=item B<[--masked_seq num]>

0 for unmasked sequence (default); 1 for soft-masked sequence;
2 for hard-masked sequence

=item B<[--output_format clustalw|fasta|...]>

The type of output you want. Both fasta and clustalw have been tested.
In fasta format, a line containg a hash ("#") is added at the end of
each alignment. "Fasta" is the default format.

NB: This script uses the Bio::AlignIO::xxx modules to format the output
except for the maf format as writting is not support by the module.
Instead, this script does the formatting itself for maf.

=item B<[--output_file filename]>

The name of the output file. By default the output is the
standard output

=item B<[--split_size split_size]>

Only available when dumping all the alignments in one go
(without using the coordinate_system nor the seq_region_name
options) to split the output in several files. Each file
will contain up to split-size alignments. Obviously, you
need to specify a output file name, which will be used as base
for the name of all the files.

=item B<[--chunk_num chunk_num]>

Only available when dumping all the alignments in one go
(without using the coordinate_system nor the seq_region_name
options) and spliting them in several files. This option is
used to dump one of the files only (the first file is num. 1)

=back

=head1 EXAMPLES

=over

=item Dump all the human-mouse alignment on human chromosome X [1Mb-2Mb] in a multi fasta format:

perl DumpMultiAlign.pl --species "Homo sapiens" \
  --set_of_alignments "Homo sapiens:Mus musculus" \
  --seq_region X --seq_region_start 1000000 \
  --seq_region_end 2000000 --output_format fasta

=item Dump all the human-mouse alignment on human supercontigs in a clustalw format:

perl DumpMultiAlign.pl --species "Homo sapiens" \
  --set_of_alignments "Homo sapiens:Mus musculus" \
  --coord_system supercontig --output_format clustalw

=item Dump all the human-chicken alignment on human chromosome 1, returning soft-masked sequences:

perl DumpMultiAlign.pl --species "Homo sapiens" \
  --set_of_alignments "Homo sapiens:Mus musculus" \
  --seq_region 1 --masked_seq 1

=cut

my $usage = qq{
perl DumpMultiAlign.pl
  Getting help:
    [--help]
  
  General configuration:
    [--reg_conf registry_configuration_file]
        the Bio::EnsEMBL::Registry configuration file. If none given,
        the one set in ENSEMBL_REGISTRY will be used if defined, if not
        ~/.ensembl_init will be used.
    [--dbname compara_db_name]
        the name of compara DB in the registry_configuration_file or any
        of its aliases. Uses "compara" by default.

  For the query slice:
    [--species species]
        Query species. Default is "human"
    --seq_region region_name
        Query region name, i.e. the chromosome name
    --seq_region_start start
    --seq_region_end end
    [--coord_system coordinates_name]
        By default this script dumps for one particular top-level seq_region.
        This option allows to dump, for instance, all the alignments on all
        the top-level supercontig in one go.

  For the alignments:
    [--alignment_type method_link_name]
        The type of alignment. Default is "BLASTZ_NET"
    [--set_of_species species1:species2:species3:...]
        The list of species used to get those alignments. Default is
        "human:mouse". The names should correspond to the name of the
        core database in the registry_configuration_file or any of its
        aliases

  Ouput:
    [--original_seq]
        Dumps orignal sequences instead of the aligned ones.
        NB: This won't work properly with some file formats
        like clustalw
    [--masked_seq num]
        0 for unmasked sequence (default); 1 for soft-masked sequence;
        2 for hard-masked sequence
    [--output_format clustalw|fasta|...]
        The type of output you want. "fasta" is the default.
    [--output_file filename]
        The name of the output file. By default the output is the
        standard output
    [--split-size split-size]
        Only available when dumping all the alignments in one go
        (without using the coordinate_system nor the seq_region_name
        options) to split the output in several files. Each file
        will contain up to split-size alignments. Obviously, you
        need to specify a output file name, which will be used as base
        for the name of all the files.
    [--chunk_num chunk_num]
        Only available when dumping all the alignments in one go
        (without using the coordinate_system nor the seq_region_name
        options) and spliting them in several files. This option is
        used to dump one of the files only (the first file is num. 1)
};

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::LocatableSeq;
use Getopt::Long;

my $reg_conf;
my $db = 'mysql://anonymous@ensembldb.ensembl.org';
my $dbname = "Multi";
my $species = "human";
my $coord_system;
my $seq_region;
my $seq_region_start;
my $seq_region_end;
my $alignment_type = "BLASTZ_NET";
my $set_of_species = "human:mouse";
my $original_seq = undef;
my $masked_seq = 0;
my $output_file = undef;
my $output_format = "fasta";
my $split_size;
my $chunk_num;
my $help;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "db=s" => \$db,
    "dbname=s" => \$dbname,
    "species=s" => \$species,
    "coord_system=s" => \$coord_system,
    "seq_region=s" => \$seq_region,
    "seq_region_start=i" => \$seq_region_start,
    "seq_region_end=i" => \$seq_region_end,
    "alignment_type=s" => \$alignment_type,
    "set_of_species=s" => \$set_of_species,
    "original_seq" => \$original_seq,
    "masked_seq=i" => \$masked_seq,
    "output_format=s" => \$output_format,
    "output_file=s" => \$output_file,
    "split_size=s" => \$split_size,
    "chunk_num=s" => \$chunk_num,
  );

# Print Help and exit
if ($help) {
  print $description, $usage;
  exit(0);
}

# Configure the Bio::EnsEMBL::Registry
# Uses $reg_conf if supllied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses ~/.ensembl_init
# if all the previous fail.
if ($reg_conf) {
  Bio::EnsEMBL::Registry->load_all($reg_conf);
} else {
  Bio::EnsEMBL::Registry->load_registry_from_url($db);
}

# Getting all the Bio::EnsEMBL::Compara::GenomeDB objects
my $genome_dbs;
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomeDB');
throw("Registry configuration file has no data for connecting to <$dbname>")
    if (!$genome_db_adaptor);
foreach my $this_species (split(":", $set_of_species)) {
  my $this_meta_container_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
      $this_species, 'core', 'MetaContainer');
  throw("Registry configuration file has no data for connecting to <$this_species>")
      if (!$this_meta_container_adaptor);
  my $this_binomial_id = $this_meta_container_adaptor->get_Species->binomial;
  # Fetch Bio::EnsEMBL::Compara::GenomeDB object
  my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($this_binomial_id);
  # Add Bio::EnsEMBL::Compara::GenomeDB object to the list
  push(@$genome_dbs, $genome_db);
}

# Getting Bio::EnsEMBL::Compara::MethodLinkSpeciesSet obejct
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    $dbname, 'compara', 'MethodLinkSpeciesSet');
my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
        $alignment_type, $genome_dbs);
throw("The database do not contain any $alignment_type data for $set_of_species!")
    if (!$method_link_species_set);

my $conservation_score_mlss;
if ($method_link_species_set->method_link_type eq "GERP_CONSERVATION_SCORE") {
  $conservation_score_mlss = $method_link_species_set;
  my $meta_container = Bio::EnsEMBL::Registry->get_adaptor(
    $dbname, 'compara', 'MetaContainer');
  my $mlss_id = $meta_container->list_value_by_key('gerp_'.$conservation_score_mlss->dbID)->[0];
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($mlss_id);
}

# Fetching the query Slice:
my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'Slice');
throw("Registry configuration file has no data for connecting to <$species>")
    if (!$slice_adaptor);
my @query_slices;
if ($coord_system and !$seq_region) {
  @query_slices = grep {$_->coord_system_name eq $coord_system} @{$slice_adaptor->fetch_all('toplevel')};
} elsif ($coord_system) {
  my $query_slice = $slice_adaptor->fetch_by_region(
      $coord_system, $seq_region, $seq_region_start, $seq_region_end);
  throw("No Slice can be created with coordinates $seq_region:$seq_region_start-$seq_region_end")
      if (!$query_slice);
  @query_slices = ($query_slice);
} elsif ($seq_region) {
  my $query_slice = $slice_adaptor->fetch_by_region(
      'toplevel', $seq_region, $seq_region_start, $seq_region_end);
  throw("No Slice can be created with coordinates $seq_region:$seq_region_start-$seq_region_end")
      if (!$query_slice);
  @query_slices = ($query_slice);
}

# Fetching all the GenomicAlignBlock corresponding to this Slice:
my $genomic_align_block_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    $dbname, 'compara', 'GenomicAlignBlock');

my $release = Bio::EnsEMBL::Registry->get_adaptor(
    $dbname, 'compara', 'MetaContainer')->list_value_by_key("schema_version")->[0];
my $date = scalar(localtime());

if (!@query_slices) {
  my $start = 0;
  my $num = 0;
  if ($chunk_num) {
    $num = $chunk_num - 1;
    $start = $split_size * $num;
  }
  do {
    my $genomic_align_blocks =
        $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet(
            $method_link_species_set, $split_size, $start);
    last if (!@$genomic_align_blocks);
    if ($output_file and $split_size) {
      $num++;
      my $this_output_file = $output_file;
      if ($this_output_file =~ /\.[^\.]+$/) {
        $this_output_file =~ s/(\.[^\.]+)$/_$num$1/;
      } else {
        $this_output_file .= ".$num";
      }
      open(STDOUT, ">$this_output_file") or die("Cannot open $this_output_file");
    }
    if ($output_format eq "maf") {
      print "##maf version=1 program=", $method_link_species_set->method_link_type, "\n";
      print "#\n";
    } elsif ($output_format eq "emf") {
      print
        "##FORMAT (compara)\n",
        "##DATE $date\n",
        "##RELEASE ", $release, "\n",
        "# Alignments: ", $method_link_species_set->name, "\n",
        "# Region: ALL_ALIGNMENTS\n";
      print "# File $num\n" if ($num);
    }

    foreach my $this_genomic_align_block (@$genomic_align_blocks) {
      write_genomic_align_block($output_format, $this_genomic_align_block);
      $this_genomic_align_block = undef;
    }
    exit if ($chunk_num);
    exit if ($num >= 9);
    $start += $split_size;
  } while($split_size);
} else {
  if ($output_file) {
    open(STDOUT, ">$output_file") or die("Cannot open $output_file");
  }

  my $alignIO;
  if ($output_format eq "maf") {
    print "##maf version=1 program=", $method_link_species_set->method_link_type, "\n";
    print "#\n";
  } elsif ($output_format eq "emf") {
    print
      "##FORMAT (compara)\n",
      "##DESCRIPTION ", , "\n",
      "##DATE ", scalar(localtime), "\n",
      "##RELEASE ", $release, "\n",
      "# Alignments: ", $method_link_species_set->name, "\n";
    if ($coord_system and !$seq_region) {
      print "# Region: ALL ${coord_system}s\n";
    } else {
      my $slice = $query_slices[0];
      print "# Region: ",
          $slice->adaptor->db->get_MetaContainer->get_Species->binomial,
          " ", $slice->name, "\n";
    }
  } else {
    $alignIO = Bio::AlignIO->newFh(
            -interleaved => 0,
            -fh => \*STDOUT,
            -format => $output_format,
            -idlength => 10
        );
  }

  
  foreach my $this_slice (@query_slices) {
    my $genomic_align_blocks =
        $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
            $method_link_species_set, $this_slice);
  
    foreach my $this_genomic_align_block (@$genomic_align_blocks) {
      write_genomic_align_block($output_format, $this_genomic_align_block);
      $this_genomic_align_block = undef;
    }
  }
}

sub write_genomic_align_block {
  my ($output_format, $this_genomic_align_block) = @_;

  if ($output_format eq "maf") {
    return print_my_maf($this_genomic_align_block);
  } elsif ($output_format eq "emf") {
    return print_my_emf($this_genomic_align_block);
  }
  my $alignIO = Bio::AlignIO->newFh(
          -interleaved => 0,
          -fh => \*STDOUT,
          -format => $output_format,
          -idlength => 10
      );
  my $simple_align = Bio::SimpleAlign->new();
  $simple_align->id("GAB#".$this_genomic_align_block->dbID);
  $simple_align->score($this_genomic_align_block->score);

  foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_GenomicAligns}) {
    my $seq_name = $this_genomic_align->dnafrag->genome_db->name;
    $seq_name =~ s/(.)\w* (...)\w*/$1$2/;
    $seq_name .= ".".$this_genomic_align->dnafrag->name;
#     $seq_name = $simple_align->id().":".$seq_name if ($output_format eq "fasta");
    my $aligned_sequence;
    if ($masked_seq == 1) {
      $this_genomic_align->original_sequence($this_genomic_align->get_Slice->get_repeatmasked_seq(undef,1)->seq);
    } elsif ($masked_seq == 2) {
      $this_genomic_align->original_sequence($this_genomic_align->get_Slice->get_repeatmasked_seq()->seq);
    }
    if ($original_seq) {
      $aligned_sequence = $this_genomic_align->original_sequence;
    } else {
      $aligned_sequence = $this_genomic_align->aligned_sequence;
    }
    my $seq;
    if ($this_genomic_align->dnafrag_strand == -1) {
      $seq = Bio::LocatableSeq->new(
              -SEQ    => $aligned_sequence,
              -START  => $this_genomic_align->dnafrag_end,
              -END    => $this_genomic_align->dnafrag_start,
              -ID     => $seq_name,
              -STRAND => $this_genomic_align->dnafrag_strand
          );
    } else {
      $seq = Bio::LocatableSeq->new(
              -SEQ    => $aligned_sequence,
              -START  => $this_genomic_align->dnafrag_start,
              -END    => $this_genomic_align->dnafrag_end,
              -ID     => $seq_name,
              -STRAND => $this_genomic_align->dnafrag_strand
          );
    }
    $simple_align->add_seq($seq);
  }
  print $alignIO $simple_align;
  print "#\n" if ($output_format eq "fasta");
}

sub print_my_emf {
  my ($genomic_align_block) = @_;

  print "\n";
  my $aligned_seqs;
  foreach my $this_genomic_align (@{$genomic_align_block->get_all_GenomicAligns()}) {
    my $species_name = $this_genomic_align->genome_db->name;
    $species_name =~ s/ /_/g;
    print join(" ", "SEQ", $species_name, $this_genomic_align->dnafrag->name,
        $this_genomic_align->dnafrag_start, $this_genomic_align->dnafrag_end,
        $this_genomic_align->dnafrag_strand), "\n";
    my $aligned_sequence;
    if ($masked_seq == 1) {
      $this_genomic_align->original_sequence($this_genomic_align->get_Slice->get_repeatmasked_seq(undef,1)->seq);
    } elsif ($masked_seq == 2) {
      $this_genomic_align->original_sequence($this_genomic_align->get_Slice->get_repeatmasked_seq()->seq);
    }
    if ($original_seq) {
      $aligned_sequence = $this_genomic_align->original_sequence;
    } else {
      $aligned_sequence = $this_genomic_align->aligned_sequence;
    }
    for (my $i = 0; $i<length($aligned_sequence); $i++) {
      $aligned_seqs->[$i] .= substr($aligned_sequence, $i, 1);
    }
  }
  if ($conservation_score_mlss) {
    print "SCORE ", $conservation_score_mlss->name, "\n";
    my $conservation_scores = $genomic_align_block->adaptor->db->get_ConservationScoreAdaptor->
        fetch_all_by_GenomicAlignBlock($genomic_align_block, undef, undef, undef,
            $genomic_align_block->length, undef, 1);
    my $this_conservation_score = shift @$conservation_scores;
    for (my $i = 0; $i<@$aligned_seqs; $i++) {
      if ($this_conservation_score and $this_conservation_score->position == $i + 1) {
        $aligned_seqs->[$i] .= sprintf(" %.2f", $this_conservation_score->diff_score);
        $this_conservation_score = shift @$conservation_scores;
      } else {
        $aligned_seqs->[$i] .= " .";
      }
    }
  }
  print "DATA\n";
  print join("\n", @$aligned_seqs);
  print "\n//\n";
}


sub print_my_maf {
  my ($genomic_align_block) = @_;

  print "a";
  if (defined $genomic_align_block->score) {
    print " score=", $genomic_align_block->score;
  }
  print "\n";
  foreach my $this_genomic_align (@{$genomic_align_block->get_all_GenomicAligns()}) {
    my $seq_name = $this_genomic_align->dnafrag->genome_db->name;
    $seq_name =~ s/(.)\w* (...)\w*/$1$2/;
    $seq_name .= ".".$this_genomic_align->dnafrag->name;
    my $aligned_sequence;
    if ($masked_seq == 1) {
      $this_genomic_align->original_sequence($this_genomic_align->get_Slice->get_repeatmasked_seq(undef,1)->seq);
    } elsif ($masked_seq == 2) {
      $this_genomic_align->original_sequence($this_genomic_align->get_Slice->get_repeatmasked_seq()->seq);
    }
    if ($original_seq) {
      $aligned_sequence = $this_genomic_align->original_sequence;
    } else {
      $aligned_sequence = $this_genomic_align->aligned_sequence;
    }
    if ($this_genomic_align->dnafrag_strand == 1) {
      printf("s %-20s %10d %10d + %10d %s\n",
          $seq_name,
          $this_genomic_align->dnafrag_start-1,
          ($this_genomic_align->dnafrag_end - $this_genomic_align->dnafrag_start + 1),
          $this_genomic_align->dnafrag->length,
          $aligned_sequence);
    } else {
      printf("s %-20s %10d %10d - %10d %s\n",
          $seq_name,
          ($this_genomic_align->dnafrag->length - $this_genomic_align->dnafrag_end),
          ($this_genomic_align->dnafrag_end - $this_genomic_align->dnafrag_start + 1),
          $this_genomic_align->dnafrag->length,
          $aligned_sequence);
    }
  }
  print "\n";
}

exit;
