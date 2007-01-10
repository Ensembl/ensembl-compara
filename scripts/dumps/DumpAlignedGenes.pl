#!/usr/local/ensembl/bin/perl -w

use strict;

my $description = q{
###########################################################################
##
## PROGRAM DumpAlignedGenes.pl
##
## AUTHORS
##    Javier Herrero (jherrero@ebi.ac.uk)
##
## COPYRIGHT
##    This modules is part of the Ensembl project http://www.ensembl.org
##
## DESCRIPTION
##    This script dumps aligned genes. Genes are aligned using the either
##    pairwise or multiple genomic alignments.
##
###########################################################################

};

=head1 NAME

DumpAlignedGenes.pl

=head1 AUTHORS

 Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

This script is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script dumps aligned genes. Genes are aligned using the either
pairwise or multiple genomic alignments.

=head1 SYNOPSIS

perl DumpMultiAlign.pl --species human --seq_region 14 --seq_region_start 75000000
    --seq_region_end 75010000 --genes_from mouse --alignment_type BLASTZ_NET
    --set_of_species human:mouse

perl DumpMultiAlign.pl
    [--reg_conf registry_configuration_file]
    [--dbname compara_db_name]
    [--species species]
    [--coord_system coordinates_name]
    --seq_region region_name
    --seq_region_start start
    --seq_region_end end
    --genes_from species
    [--max_repetition_length ]
    [--max_gap_length ]
    [--max_intron_length]
    [--[no]strict_order_of_exon_pieces]
    [--[no]strict_order_of_exons]
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

=head2 SPECIFYING THE MAPPING

=over

=item B<[--genes_from species]>

Source species. If you want to map mouse genes on human chromosomes, this will
be 'Mus musculus' or any alias

=item B<[--max_repetition_length max]>

Default 100. Join or link two pieces of an exon if they do not
overlap more than 100 bp

=item B<[--max_gap_length max]>

Default 100. Join two pieces of an exon if the separation between
them is not larger than 100 bp. Setting this to -1 disable any
joining event.

=item B<[--max_intron_length]>

Default 100000. Link two exons if the separation between
them is not larger than 100000 bp. Setting this to -1 disable any
linking event.

=item B<[--[no]strict_order_of_exon_pieces]>
        
Do not [or do] merge two pieces of an exon if they are not in the
right order after mapping
    
=item B<[--[no]strict_order_of_exons]>

Do not [or do] link two exons if they are not in the right order
after mapping

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

=item B<[--expanded]>
  
By default the genes are aligned on the original query species.
In the expanded mode, the deletions in the query species are taken
into account and represented in the output. Default is "condensed"
mode.

=back

=head2 OUTPUT

=over

=item B<[--output_file filename]>
  
The name of the output file. By default the output is the
standard output

=back

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::LocatableSeq;
use Getopt::Long;

my $usage = qq{
perl DumpAlignedGenes.pl
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

  For the mapping:
    [--genes_from species]
        If you want to map rat genes on human chromosomes, this will
        be 'Rattus norvegicus' or any alias
    [--max_repetition_length ]
        Default 100. Join or link two pieces of an exon if they do not
        overlap more than 100 bp
    [--max_gap_length ]
        Default 100. Join two pieces of an exon if the separation between
        them is not larger than 100 bp. Setting this to -1 disable any
        joining event.
    [--max_intron_length]
        Default 100000. Link two exons if the separation between
        them is not larger than 100000 bp. Setting this to -1 disable any
        linking event.
    [--[no]strict_order_of_exon_pieces]
        Do not [or do] merge two pieces of an exon if they are not in the
        right order after mapping
    [--[no]strict_order_of_exons]
        Do not [or do] link two exons if they are not in the right order
        after mapping

  For the alignments:
    [--alignment_type method_link_name]
        The type of alignment. Default is "BLASTZ_NET"
    [--set_of_species species1:species2:species3:...]
        The list of species used to get those alignments. Default is
        "human:mouse". The names should correspond to the name of the
        core database in the registry_configuration_file or any of its
        aliases
    [--expanded]
        By default the genes are aligned on the original query species.
        In the expanded mode, the deletions in the query species are taken
        into account and represented in the output. Default is "condensed"
        mode.

  Ouput:
    [--output_file filename]
        The name of the output file. By default the output is the
        standard output
};

my $reg_conf;
my $dbname = "compara";
my $species = "human";
my $coord_system = "chromosome";
my $seq_region = "14";
my $seq_region_start = 50000000;
my $seq_region_end =   50250000;
my $source_species = "rat"; ## for genes_from
my $alignment_type = "BLASTZ_NET";
my $set_of_species = "human:rat";
my $expanded = 0;
my $output_file = undef;
my $max_repetition_length = 100;
my $max_gap_length = 100;
my $max_intron_length = 100000;
my $strict_order_of_exon_pieces = 1;
my $strict_order_of_exons = 0;
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

    "genes_from=s" => \$source_species,
    "max_repetition_length=i" => \$max_repetition_length,
    "max_gap_length=i" => \$max_gap_length,
    "max_intron_length=i" => \$max_intron_length,
    "strict_order_of_exon_pieces!" => \$strict_order_of_exon_pieces,
    "strict_order_of_exons!" => \$strict_order_of_exons,

    "alignment_type=s" => \$alignment_type,
    "set_of_species=s" => \$set_of_species,
    "expanded!" => \$expanded,
    "output_file=s" => \$output_file,
  );

# Print Help and exit if help is requested
if ($help) {
  print $description, $usage;
  exit(0);
}

##############################################################################################
##
## Redirect STDOUT to $output_file if specified
##

if ($output_file) {
  open(STDOUT, ">$output_file") or die("Cannot open $output_file");
}

##
##############################################################################################


##############################################################################################
##
## Configure the Bio::EnsEMBL::Registry
## Uses $reg_conf if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses
## ~/.ensembl_init if all the previous fail.
##

Bio::EnsEMBL::Registry->load_all($reg_conf);

##
##############################################################################################

##############################################################################################
##
## Getting all the Bio::EnsEMBL::Compara::GenomeDB objects corresponding to the set of
## species. They will be used for fetching the right MethodLinkSpeciesSet object
##

my $genome_dbs;

# Get the adaptor
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomeDB');

# Check adaptor
throw("Registry configuration file has no data for connecting to <$dbname>")
    if (!$genome_db_adaptor);

# Fill in the @$genome_dbs array.
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

##
##############################################################################################


##############################################################################################
##
## Getting the Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
##

# Get the adaptor
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    $dbname, 'compara', 'MethodLinkSpeciesSet');

# Fetch the object
my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
        $alignment_type, $genome_dbs);

# Check the object
throw("The database do not contain any $alignment_type data for $set_of_species!")
    if (!$method_link_species_set);

##
##############################################################################################


##############################################################################################
##
## Fetching the query Slice:
##

# Get the adaptor
my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'Slice');

# Check the adaptor
throw("Registry configuration file has no data for connecting to <$species>")
    if (!$slice_adaptor);

# Fetch the object
my $query_slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region, $seq_region_start, $seq_region_end);

# Check the object
throw("No Slice can be created with coordinates $seq_region:$seq_region_start-$seq_region_end")
    if (!$query_slice);

##
##############################################################################################


##############################################################################################
##
## Fetching Genome DB adaptor for the source species
##

# Get the MetaContainer adaptor
my $meta_container_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    $source_species, 'core', 'MetaContainer');

# Check the adaptor
throw("Registry configuration file has no data for connecting to <$source_species>")
    if (!$meta_container_adaptor);

# Get the binomial name for this species from the MetaContainer adaptor
my $source_binomial_id = $meta_container_adaptor->get_Species->binomial;

# Fetch the Bio::EnsEMBL::Compara::GenomeDB object
my $source_genome_db = $genome_db_adaptor->fetch_by_name_assembly($source_binomial_id);

##
##############################################################################################


##############################################################################################
##
## Fetching the aligned Genes:
##

# Get the Bio::EnsEMBL::Compara::DBSQL::AlignSliceAdaptor
my $align_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'AlignSlice');

# Fetch the Bio::EnsEMBL::Compara::AlignSlice object using the query Slice and the 
# MethodLinkSpeciesSet object corresponding to the set of species
my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
        $query_slice,
        $method_link_species_set,
        $expanded
    );

# Get all the genes from the source species and map them on the query genome
my $mapped_genes = $align_slice->{slices}->{$source_genome_db->name}->get_all_Genes(
        -MAX_REPETITION_LENGTH => 100,
        -MAX_GAP_LENGTH => 100,
        -MAX_INTRON_LENGTH => 100000,
        -STRICT_ORDER_OF_EXON_PIECES => 1,
        -STRICT_ORDER_OF_EXONS => 0
    );

##
##############################################################################################


##############################################################################################
##
## Print the aligned genes on the genomic sequence they are aligned to
##

$meta_container_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    $species, 'core', 'MetaContainer');
throw("Registry configuration file has no data for connecting to <$species>")
    if (!$meta_container_adaptor);
my $query_binomial_id = $meta_container_adaptor->get_Species->binomial;
my $query_genome_db = $genome_db_adaptor->fetch_by_name_assembly($query_binomial_id);

foreach my $gene (sort {$a->stable_id cmp $b->stable_id} @$mapped_genes) {
  print "GENE: ", $gene->stable_id,
      " (", ($seq_region_start + $gene->start), "-", ($seq_region_start + $gene->end), ")\n";
  foreach my $transcript (sort {$a->stable_id cmp $b->stable_id} @{$gene->get_all_Transcripts}) {
    print " + TRANSCRIPT: ", $transcript->stable_id,
        " (", ($seq_region_start + $transcript->start), "-", ($seq_region_start + $transcript->end),
        ") [", $transcript->strand, "]\n";
    print " + TRANSLATION: (",
        ($seq_region_start + $transcript->coding_region_start), "-",
        ($seq_region_start + $transcript->coding_region_end), ")\n" if ($transcript->translation);
    foreach my $exon (@{$transcript->get_all_Exons}) {
      if (defined($exon->start)) {
        print "   + EXON: ", $exon->stable_id, " (", ($exon->start or "***"), "-", ($exon->end or "***"), ") [",
            $exon->strand, "] -- (", $exon->get_aligned_start, "-", $exon->get_aligned_end, ")  ",
            " -- (", $exon->exon->start, " - ", $exon->exon->end, " ", $exon->exon->strand, ")   -- ",
            ($exon->original_rank or "*"), " ",
            $exon->cigar_line, "\n";
      } else {
        print "   + EXON: ", $exon->stable_id, "    -- ",
            "(", $exon->exon->start, " - ", $exon->exon->end, " ", $exon->exon->strand, ")   -- ",
            $exon->original_rank, "\n";
        next;
      }

      my $seq;
      if ($exon->strand == 1) {
        $seq = ("." x 50).$exon->seq->seq.("." x 50);
      } else {
        $seq = ("." x 50).$exon->seq->revcom->seq.("." x 50);
      }
      my $aseq = $align_slice->{slices}->{$query_genome_db->name}->subseq($exon->start-50, $exon->end+50);
      $seq =~ s/(.{80})/$1\n/g;
      $aseq =~ s/(.{80})/$1\n/g;
      $seq =~ s/(.{20})/$1 /g;
      $aseq =~ s/(.{20})/$1 /g;
      my @seq = split("\n", $seq);
      my @aseq = split("\n", $aseq);
      for (my $a=0; $a<@seq; $a++) {
        print "     ", $seq[$a], "\n";
        print "     ", $aseq[$a], "\n";
        print "\n";
      }
    }
  }
}

##
##############################################################################################


exit;
