#!/usr/local/ensembl/bin/perl -w

my $description = q{
###########################################################################
##
## PROGRAM DumpAlignSlice.pl
##
## AUTHORS
##    Javier Herrero (jherrero@ebi.ac.uk)
##
## COPYRIGHT
##    This modules is part of the Ensembl project http://www.ensembl.org
##
## DESCRIPTION
##    This script dumps genomic alignments from an EnsEMBL Compara
##    database using the AlignSlice framework. It can work in both
##    collapsed (preserving the original sequence) and expanded mode
##    (expanding the original sequence in order to accommodate the
##    gaps defined by the genomic alignment).
##
###########################################################################

};

=head1 NAME

DumpAlignSlice.pl

=head1 AUTHORS

 Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

This script is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script dumps genomic alignments from an EnsEMBL Compara
database using the AlignSlice framework. It can work in both
colapsed (preserving the original sequence) and expanded mode
(expanding the original sequence in order to accomodate the
gaps defined by the genomic alignment).

=head1 SYNOPSIS

perl DumpAlignSlice.pl --species human --seq_region 14 --seq_region_start 75000000
    --seq_region_end 75010000 --alignment_type BLASTZ_NET --set_of_species mouse:rat:dog

perl DumpAlignSlice.pl
    [--reg_conf registry_configuration_file]
    [--dbname compara_db_name]
    [--species query_species]
    [--coord_system coordinates_name]
    --seq_region region_name
    --seq_region_start start
    --seq_region_end end
    [--seq_region_strand strand]
    [--alignment_type method_link_name]
    [--set_of_species species1:species2:species3:...]
    [--[no]condensed]
    [--[no]solve_overlapping]
    [--[no]print_genomic]
    [--[no]print_contigs]
    [--[no]print_genes]
    [--[no]print_variations]
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

=item B<[--species query_species]>
  
Query species. Default is "human"

=item B<[--coord_system coordinates_name]>
  
Query coordinate system. Default is "chromosome"

=item B<--seq_region region_name>
  
Query region name, i.e. the chromosome name

=item B<--seq_region_start start>

=item B<--seq_region_end end>

=item B<[--seq_region_strand strand]>

The strand of the query. It can be either +1 or -1. Default is -1.

=back

=head2 SPECIFYING THE ALIGNMENT TYPE

=over

=item B<[--alignment_type method_link_name]>
  
The type of alignment. Default is "BLASTZ_NET"

=item B<[--set_of_species species1:species2:species3:...]>
  
The list of other species used to fetch original pairwise alignments
and build fake multiple one. Default is "mouse:rat". The names
should correspond to the name of the core database in the
registry_configuration_file or any of its aliases

=item B<[--[no]condensed]>

By default, the AlignSlice is created in "expanded" mode. Use
this option for getting the AlignSlice in "condensed" mode

=item B<[--[no]solve_overlpping]>

By default, the AlignSlice ignores overlapping alignments. 
This option will reconciliate them by means of a fake
alignment.

=back

=head2 OUTPUT

=over

=item B<[--[no]print_genomic]>

You can add the genomic sequence to the alignmnent (default: YES)

=item B<[--[no]print_contigs]>

You can add the contigs to the alignment (default: NO)

=item B<[--[no]print_genes]>

Add genes (transcripts) to the alignment.  (default: NO)

=item B<[--[no]print_variations]>

Add SNPs (variations) to the alignment.  (default: NO)

SNPs will be represented by the alternative nucleotide. All other types of
variations are represented by a "*".

=item B<[--output_format clustalw|fasta|...]>
  
The type of output you want. "clustalw" is the default.

=item B<[--output_file filename]>
  
The name of the output file. By default the output is the
standard output

=back

=cut

my $usage = qq{
perl DumpAlignSlice.pl
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
    [--species query_species]
        Query species. Default is "human"
    [--coord_system coordinates_name]
        Query coordinate system. Default is "chromosome"
    --seq_region region_name
        Query region name, i.e. the chromosome name
    --seq_region_start start
    --seq_region_end end
    [--seq_region_strand strand]
        Can be 1 or -1. Default is "+1"

  For the alignments:
    [--alignment_type method_link_name]
        The type of alignment. Default is "MAVID"
    [--set_of_species species1:species2:species3:...]
        The list of other species used to fetch original pairwise alignments
        and build fake multiple one. Default is "mouse:rat". The names
        should correspond to the name of the core database in the
        registry_configuration_file or any of its aliases
    [--[no]condensed]
        By default, the AlignSlice is created in "expanded" mode. Use
        this option for getting the AlignSlice in "condensed" mode
    [--[no]solve_overlapping]
        By default, the AlignSlice ignores overlapping alignments. 
        This option will reconciliate them by means of a fake
        alignment.

  Ouput:
    [--[no]print_genomic]
        You can add the genomic sequence to the alignmnent (default: YES)
    [--[no]print_contigs]
        You can add the contigs to the alignment (default: NO)
    [--[no]print_genes]
        Add genes (transcripts) to the alignment.  (default: NO)
    [--[no]print_variations]
        Add SNPs (variations) to the alignment.  (default: NO)
        SNPs will be represented by the alternative nucleotide. All
        other types of variations are represented by a "*".
    [--output_format clustalw|fasta|...]
        The type of output you want. "clustalw" is the default.
    [--output_file filename]
        The name of the output file. By default the output is the
        standard output
};

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::AlignSlice;
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::LocatableSeq;
use Getopt::Long;
#chr7:73549956-73613012
my $reg_conf;
my $dbname = "compara";
my $query_species = "human";
my $coord_system = "chromosome";
my $seq_region = "7";
my $seq_region_start = 73549956;
my $seq_region_end = 73549966;
my $seq_region_strand = 1;
my $alignment_type = "MAVID";
my $set_of_species = "mouse:rat";
my $condensed = 0;
my $solve_overlapping = 0;
my $print_genomic = 1;
my $print_genes = 0;
my $print_contigs = 0;
my $print_variations = 0;
my $output_file = undef;
my $output_format = "clustalw";
my $help;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "dbname=s" => \$dbname,
    "species=s" => \$query_species,
    "coord_system=s" => \$coord_system,
    "seq_region=s" => \$seq_region,
    "seq_region_start=i" => \$seq_region_start,
    "seq_region_end=i" => \$seq_region_end,
    "seq_region_strand=i" => \$seq_region_strand,
    "alignment_type=s" => \$alignment_type,
    "set_of_species=s" => \$set_of_species,
    "condensed!" => \$condensed,
    "solve_overlapping!" => \$solve_overlapping,
    "print_genomic!" => \$print_genomic,
    "print_genes!" => \$print_genes,
    "print_contigs!" => \$print_contigs,
    "print_variations!" => \$print_variations,
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
# Uses $reg_conf if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses ~/.ensembl_init
# if all the previous fail.
Bio::EnsEMBL::Registry->load_all($reg_conf);

# Fetching the query Slice:
my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($query_species, 'core', 'Slice');
throw("Registry configuration file has no data for connecting to <$query_species>")
    if (!$slice_adaptor);
my $query_slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region, $seq_region_start, $seq_region_end, $seq_region_strand);
throw("No Slice can be created with coordinates $seq_region:$seq_region_start-$seq_region_end")
    if (!$query_slice);

# Getting all the Bio::EnsEMBL::Compara::GenomeDB objects
my $genome_db;
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomeDB');
throw("Registry configuration file has no data for connecting to <$dbname>")
    if (!$genome_db_adaptor);
foreach my $this_species ($query_species, split(":", $set_of_species)) {
  my $this_meta_container_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
      $this_species, 'core', 'MetaContainer');
  throw("Registry configuration file has no data for connecting to <$this_species>")
      if (!$this_meta_container_adaptor);
  my $this_binomial_id = $this_meta_container_adaptor->get_Species->binomial;

  # Fetch Bio::EnsEMBL::Compara::GenomeDB object
  $genome_db->{$this_species} = $genome_db_adaptor->fetch_by_name_assembly($this_binomial_id);
}
    
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
        $dbname,
        'compara',
        'MethodLinkSpeciesSet'
    );
my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
      $alignment_type, [values(%$genome_db)]);
throw("The database does not contain any $alignment_type data for ".join(", ", keys(%$genome_db))."!")
    if (!$method_link_species_set);

## Create an AlignSlice for projecting on query_slice
my $align_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, "compara", "AlignSlice");
my $align_slice = $align_slice_adaptor->fetch_by_Slice_MethodLinkSpeciesSet(
        $query_slice, $method_link_species_set, !$condensed, $solve_overlapping
    );
my $simple_align;
if ($print_genomic) {
  $simple_align = $align_slice->get_SimpleAlign();
} else {
  $simple_align = new Bio::SimpleAlign;
}

if ($print_contigs) {
  foreach my $slice (@{$align_slice->get_all_Slices()}) {
    foreach my $projection_segment (@{($slice->project("contig") or [])}) {
      my $this_seq = "." x $slice->length;
      my $start = $projection_segment->from_start;
      my $end = $projection_segment->from_end;
      my $seq;
      if ($start <= $end) {
        substr($this_seq, $start - 1, ($end - $start + 1), $slice->subseq($start, $end, 1));
        $seq = Bio::LocatableSeq->new(
                -SEQ    => $this_seq,
                -START  => $start,
                -END    => $end,
                -ID     => $projection_segment->to_Slice->seq_region_name."(+)",
                -STRAND => 1
            );
      } else {
        substr($this_seq, $end - 1, ($start - $end + 1), $slice->subseq($end, $start));
        $seq = Bio::LocatableSeq->new(
                -SEQ    => $this_seq,
                -START  => $end,
                -END    => $start,
                -ID     => $projection_segment->to_Slice->seq_region_name."(-)",
                -STRAND => -1
            );
      }
      $simple_align->add_seq($seq);
    }
  }
}

if ($print_genes) {
  foreach my $slice (@{$align_slice->get_all_Slices}) {
    foreach my $gene (@{$slice->get_all_Genes()}) {
      foreach my $transcript (@{$gene->get_all_Transcripts()}) {
        my $this_seq = "." x $slice->length;
        foreach my $exon (@{$transcript->get_all_Exons()}) {
          if (defined($exon->start)) {
            substr($this_seq, $exon->start - 1, $exon->length, $exon->seq->seq);
          }
        }
        my $seq = Bio::LocatableSeq->new(
                -SEQ    => $this_seq,
                -START  => $transcript->start,
                -END    => $transcript->end,
                -ID     => $transcript->stable_id.(($transcript->strand==-1)?"(-)":"(+)"),
                -STRAND => $transcript->strand
            );
        $simple_align->add_seq($seq);
      }
    }
  }
}

if ($print_variations) {
  foreach my $slice (@{$align_slice->get_all_Slices}) {
    my $count = 0;
    my $this_seq = "." x $slice->length;
    my $all_variation_features = $slice->get_all_VariationFeatures();
    next if (!@$all_variation_features);
    foreach my $variation_feature (@$all_variation_features) {
      if ($variation_feature->allele_string =~ /^\w\/(\w)$/) {
        substr($this_seq, $variation_feature->start - 1, 1, $1);
      } else {
        substr($this_seq, $variation_feature->start - 1, 1, "*");
      }
    }
    my $seq = Bio::LocatableSeq->new(
            -SEQ    => $this_seq,
            -START  => $slice->start,
            -END    => $slice->end,
            -ID     => "*".$slice->genome_db->name."*",
            -STRAND => $slice->strand
        );
    $simple_align->add_seq($seq);
  }
}

my $alignIO = Bio::AlignIO->newFh(
        -interleaved => 0,
        -fh => \*STDOUT,
        -format => $output_format,
        -idlength => 10
    );

print $alignIO $simple_align;

exit();
