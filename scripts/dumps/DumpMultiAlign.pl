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

=item B<[--reg_conf registry_configuration_file]>

the Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<[--dbname compara_db_name]>
  
the name of compara DB in the registry_configuration_file or any
of its aliases. Uses "compara" by default.

=back

=head2 SPECIFYING THE QUERY SLICE

=over

=item B<[--species species]>
  
Query species. Default is "human"

=item B<[--coord_system coordinates_name]>
  
Query coordinate system. Default is "chromosome"

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

The type of output you want. "clustalw" is the default.

=item B<[--output_file filename]>

The name of the output file. By default the output is the
standard output

=back

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
    [--coord_system coordinates_name]
        Query coordinate system. Default is "chromosome"
    --seq_region region_name
        Query region name, i.e. the chromosome name
    --seq_region_start start
    --seq_region_end end

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
};

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::LocatableSeq;
use Getopt::Long;

my $reg_conf;
my $dbname = "compara";
my $species = "human";
my $coord_system = "chromosome";
my $seq_region = "14";
my $seq_region_start = 75000000;
my $seq_region_end = 75010000;
my $alignment_type = "BLASTZ_NET";
my $set_of_species = "human:mouse";
my $original_seq = undef;
my $masked_seq = 0;
my $output_file = undef;
my $output_format = "fasta";
my $help;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
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
  );

# Print Help and exit
if ($help) {
  print $description, $usage;
  exit(0);
}

if ($output_file) {
  open(STDOUT, ">$output_file") or die("Cannot open $output_file");
}

# Configure the Bio::EnsEMBL::Registry
# Uses $reg_conf if supllied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses ~/.ensembl_init
# if all the previous fail.
Bio::EnsEMBL::Registry->load_all($reg_conf);

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

# Fetching the query Slice:
my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'Slice');
throw("Registry configuration file has no data for connecting to <$species>")
    if (!$slice_adaptor);
my $query_slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region, $seq_region_start, $seq_region_end);
throw("No Slice can be created with coordinates $seq_region:$seq_region_start-$seq_region_end")
    if (!$query_slice);

# Fetching all the GenomicAlignBlock corresponding to this Slice:
my $genomic_align_block_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    $dbname, 'compara', 'GenomicAlignBlock');
my $genomic_align_blocks =
    $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
        $method_link_species_set, $query_slice);

my $all_aligns;
foreach my $this_genomic_align_block (@$genomic_align_blocks) {
  my $simple_align = Bio::SimpleAlign->new();
  $simple_align->id("GAB#".$this_genomic_align_block->dbID);
  $simple_align->score($this_genomic_align_block->score);

  foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_GenomicAligns}) {
    my $seq_name = $this_genomic_align->dnafrag->genome_db->name;
    $seq_name =~ s/(.)\w* (.)\w*/$1$2/;
    $seq_name .= $this_genomic_align->dnafrag->name;
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
  push(@$all_aligns, $simple_align);
}

my $alignIO = Bio::AlignIO->newFh(
        -interleaved => 0,
        -fh => \*STDOUT,
        -format => $output_format,
        -idlength => 10
    );
  
foreach my $this_align (@$all_aligns) {
  print $alignIO $this_align;
}

exit;
