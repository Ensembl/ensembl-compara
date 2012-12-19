use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::LocatableSeq;
use Getopt::Long;

my $usage = qq{
perl DumpMultiAlign.pl
  Getting help:
    [--help]

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
    [--output_format clustalw|fasta|...]
        The type of output you want. "clustalw" is the default.
    [--output_file filename]
        The name of the output file. By default the output is the
        standard output
};

my $species = "human";
my $coord_system = "chromosome";
my $seq_region = "14";
my $seq_region_start = 75000000;
my $seq_region_end = 75010000;
my $alignment_type = "BLASTZ_NET";
my $set_of_species = "human:mouse";
my $output_file = undef;
my $output_format = "clustalw";
my $help;

GetOptions(
    "help" => \$help,
    "species=s" => \$species,
    "coord_system=s" => \$coord_system,
    "seq_region=s" => \$seq_region,
    "seq_region_start=i" => \$seq_region_start,
    "seq_region_end=i" => \$seq_region_end,
    "alignment_type=s" => \$alignment_type,
    "set_of_species=s" => \$set_of_species,
    "output_format=s" => \$output_format,
    "output_file=s" => \$output_file);

# Print Help and exit
if ($help) {
    print $usage;
    exit(0);
}

if ($output_file) {
    open(STDOUT, ">$output_file") or die("Cannot open $output_file");
}

Bio::EnsEMBL::Registry->load_registry_from_db(
    -host => 'ensembldb.ensembl.org', -user => 'anonymous');

# Getting all the Bio::EnsEMBL::Compara::GenomeDB objects
my $genome_dbs;
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    'Multi', 'compara', 'GenomeDB');

throw("Cannot connect to Compara") if (!$genome_db_adaptor);

foreach my $this_species (split(":", $set_of_species)) {
    my $this_meta_container_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
        $this_species, 'core', 'MetaContainer');

    throw("Registry configuration file has no data for connecting to <$this_species>")
        if (!$this_meta_container_adaptor);

    my $this_production_name = $this_meta_container_adaptor->get_production_name;

    # Fetch Bio::EnsEMBL::Compara::GenomeDB object
    my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($this_production_name);

    # Add Bio::EnsEMBL::Compara::GenomeDB object to the list
    push(@$genome_dbs, $genome_db);
}

# Getting Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    'Multi', 'compara', 'MethodLinkSpeciesSet');

my $method_link_species_set =
    $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
      $alignment_type, 
      $genome_dbs);

throw("The database do not contain any $alignment_type data for $set_of_species!")
    if (!$method_link_species_set);

# Fetching the query Slice:
my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'Slice');

throw("Registry configuration file has no data for connecting to <$species>")
    if (!$slice_adaptor);

my $query_slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region, $seq_region_start, $seq_region_end);

throw("No Slice can be created with coordinates $seq_region:$seq_region_start-".
    "$seq_region_end") if (!$query_slice);

# Fetching all the GenomicAlignBlock corresponding to this Slice:
my $genomic_align_block_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    'Multi', 'compara', 'GenomicAlignBlock');

my $genomic_align_blocks =
    $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
      $method_link_species_set, 
      $query_slice);

my $all_aligns;

# Get a Bio::SimpleAlign object from every GenomicAlignBlock
foreach my $this_genomic_align_block (@$genomic_align_blocks) {
    my $simple_align = $this_genomic_align_block->get_SimpleAlign;
    push(@$all_aligns, $simple_align);
}

# print all the genomic alignments using a Bio::AlignIO object
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
