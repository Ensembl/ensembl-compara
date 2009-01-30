#!/usr/local/ensembl/bin/perl -w

my $description = q{
###########################################################################
##
## PROGRAM LoadUcscNetData.pl
##
## AUTHORS
##    Abel Ureta-Vidal (abel@ebi.ac.uk)
##    Javier Herrero (jherrero@ebi.ac.uk)
##
## COPYRIGHT
##    This script is part of the Ensembl project http://www.ensembl.org
##
## DESCRIPTION
##    This script read BLASTz alignments from a UCSC database and store
##    them in an EnsEMBL Compara database
##
###########################################################################

};

=head1 NAME

LoadUcscNetData.pl

=head1 AUTHORS

 Abel Ureta-Vidal (abel@ebi.ac.uk)
 Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

This script is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script read BLASTz alignments from a UCSC database and store
them in an EnsEMBL Compara database

=head1 SYNOPSIS

perl LoadUcscNetData.pl
  [--help]                    this menu
   --ucsc_dbname string       (e.g. ucscMm33Rn3) one of the ucsc source database Bio::EnsEMBL::Registry aliases
   --dbname string            (e.g. compara25) one of the compara destination database Bio::EnsEMBL::Registry aliases
   --tSpecies string          (e.g. mouse) the UCSC target species (i.e. a Bio::EnsEMBL::Registry alias)
                              to which tName refers to
   --qSpecies string          (e.g. Rn3) the UCSC query species (i.e. a Bio::EnsEMBL::Registry alias)
  [--tName string]            (e.g. chr15) one of the chromosome name used by UCSC on their target species (tSpecies)
                              on the base of which alignments will be retrieved
  [--qName string]            (e.g. chrM) one of the chromosome name used by UCSC on their query species (qSpecies)
                              on the base of which alignments will be retrieved
  [--check_length]            check the chromosome length between ucsc and ensembl, then exit
  [--method_link_type string] (e.g. BLASTZ_NET) type of alignment queried (default: BLASTZ_NET)
  [--reg_conf filepath]       the Bio::EnsEMBL::Registry configuration file. If none given, 
                              the one set in ENSEMBL_REGISTRY will be used if defined, if not
                              ~/.ensembl_init will be used.
  [--matrix filepath]         matrix file to be used to score each individual alignment
                              Format should be something like
                              A    C    G    T
                              100 -200  -100 -200
                              -200  100 -200  -100
                              -100 -200  100 -200
                              -200  -100 -200   100
                              O = 2000, E = 50
                              default will choose on the fly the right matrix for the species pair considered.
  [--show_matrix]             Shows the scoring matrix that will be used and exit. Does not start the process
                              loading a compara database. **WARNING** can only be used with the other
                              compulsory arguments
  [--max_gap_size integer]    default: 50
  [--start_net_index integer] default: 0
  [--load_chains]             Load the chains instead of the nets. default: load the nets
  [--bin_size integer]        Used for loading chains in groups (this can save a lot of memory).
                              default: 1000000
  [--[no]filter_duplicate_alignments]
                              UCSC self-chains are redundant. This option permits to filter out
                              duplicated alignments. Default: filter duplicate alignments

=head1 UCSC DATABASE TABLES

NB: Part of this information is based on the help pages of the UCSC Genome Browser (http://genome.ucsc.edu/)

=head2 chain[QUERY_SPECIES] or chrXXX_chain[QUERY_SPECIES]

This table contains the coordinates for the chains. Every chain corresponds to an alignment
using a gap scoring system that allows longer gaps than traditional affine gap scoring systems.
It can also tolerate gaps in both species simultaneously. These "double-sided" gaps can be caused by local
inversions and overlapping deletions in both species.

The term "double-sided" gap is used by UCSC in the sense of a separation in both sequences between two
aligned blocks. They can be regarded as double insertions or a non-equivalent region in the alignment.
This will split the alignment while loading it in EnsEMBL (see below).

=head2 chain[QUERY_SPECIES]Link or chrXXX_chain[QUERY_SPECIES]Link

Every chain corresponds to one or several entries in this table. A chain alignment can be decomposed in
several ungapped blocks. Each of these ungapped blocks is stored in this table

=head2 net[QUERY_SPECIES]

A net correspond to the best query/target chain for every part of the target genome. It is useful for finding
orthologous regions and for studying genome rearrangement. Due to the method used to define the nets, some
of them may correspond to a portion of a chain.

=head2 Chromosome specific tables

Depending on the pair of species (query/target), the BLASTz data may be stored in one single table or in
several ones, one per chromosome. The net data are always in one single table though. This script is able
to know by itself whether it needs to access single tables or not.

=head2 Credits for the UCSC BLASTz data

(*) Blastz was developed at Pennsylvania State University by Scott Schwartz, Zheng Zhang, and Webb Miller with advice from Ross Hardison.

(*) Lineage-specific repeats were identified by Arian Smit and his RepeatMasker program.

(*) The axtChain program was developed at the University of California at Santa Cruz by Jim Kent with advice from Webb Miller and David Haussler.

=head2 References for the UCSC data:

(*) Chiaromonte, F., Yap, V.B., Miller, W. Scoring pairwise genomic sequence alignments. Pac Symp Biocomput 2002, 115-26 (2002).

(*) Kent, W.J., Baertsch, R., Hinrichs, A., Miller, W., and Haussler, D. Evolution's cauldron: Duplication, deletion, and rearrangement in the mouse and human genomes. Proc Natl Acad Sci USA 100(20), 11484-11489 (2003).

(*) Schwartz, S., Kent, W.J., Smit, A., Zhang, Z., Baertsch, R., Hardison, R., Haussler, D., and Miller, W. Human-Mouse Alignments with BLASTZ. Genome Res. 13(1), 103-7 (2003).

=head1 LOADING UCSC DATA INTO ENSEMBL

By default, only NET data are stored in EnsEMBL, i.e. the best alignment for every part of
the target genome. Unfortunatelly, GenomicAlignBlocks cannot deal with insertions in both
sequences (this is called "double-sided gaps in the UCSC documentation) and the chain may
be divided in several GenomicAlignBlocks.

If we aim to store nets, as they can be a portion of a chain only,
the chains needs to be trimmed before being stored

=head2 Transforming the coordinates

UCSC stores the alignments as zero-based half-open intervals and uses the reverse-complemented coordinates
for the reverse strand. EnsEMBL always uses inclusive coordinates, starting at 1 and always on the forward
strand. Therefore, some coordinates transformation need to be done.

 For the forward strand:
 - ensembl_start = ucsc_start + 1
 - ensembl_end = ucsc_end

 For the reverse strand:
 - ensembl_start = chromosome_length - ucsc_end + 1
 - ensembl_end = chromosome_length - ucsc_start

=head2 Mapping UCSC random chromosomes

UCSC database cannot cope with non-chromosomic sequence. The pieces of sequence that are not assembled yet
appear in the fake chromosomes called chr1_random, chr2_random, etc. In order to map those alignments into
the EnsEMBL seq_regions, this script uses the assembly data, map the alignments on the right clones and
from them to the corresponding EnsEMBL toplevel seq_region. This process is expected to be quite simple as
no gaps should appear in the alignment because of the mapping. Nevertheless it is possible to find an
alignment spanning a gap between two contigs corresponding to the same clone. In this case, the mapping
is a bit more complex but it is still possible.

This feature is only available for genomes with chromosome specific tables and you need to have the relevant
UCSC tables in your database (see below)!

As no examples of a clone on the reverse strand have been found to date, mapping these alignments if they
fall into a clone on the reverse strand of the random chromosome is not supported at the moment.

=head2 Mapping on EnsEMBL extra assemblies

EnsEMBL might release an extra level of assembly for some low-coverage genomes like the first released cow
genome. In this case this script maps the alignments on the right contigs and from them to the corresponding
genescaffold (or any other toplevel seq_region). This process could be more complex as the EnsEMBL extra
level of assembly may introduce some gaps within the contigs or even cut them.

Mapping an alignment on two different req_regions (if the alignment end up broken in two pieces because of
the new assembly) is not allowed at the moment. The alignment is skipped and a warning message is displayed.

=head1 THINGS YOU HAVE TO DO BEFORE USING THIS SCRIPT

=head2 Setting up the databases

You have to set up a UCSC database and an EnsEMBL Compara database. Please read and
follow the instructions in the accompanying README file for downloading the relevant files and creating the
UCSC database. The EnsEMBL Compara Database can be created using the ~ensembl-compara/sql/table.sql file. You
will have to fill in the meta, taxon, genome_db and dnafrag tables.

=head2 Configure the Registry

Obviously, you have to tell the Registry system where are these databases and how to access them. You will
also need to set up an alias for the query species such as it matches the name used by UCSC. This script
expects this alias as the qSpecies name as it needs it in order to know the table names.

=head1 EXAMPLES

=head2 Loading Human-mouse UCSC nets:

  perl -w LoadUcscNetData.pl
    --ucsc_dbname ucsc_human_mouse
    --dbname jh7_compara_blastz_Hg17Mm5
    --qSpecies Mm5
    --tSpecies hg17
    --method_link_type BLASTZ_NET

=head2 Loading Human-mouse UCSC chains:

  perl -w LoadUcscNetData.pl
    --ucsc_dbname ucsc_human_mouse
    --dbname jh7_compara_blastz_Hg17Mm5
    --qSpecies Mm5
    --tSpecies hg17
    --method_link_type BLASTZ_CHAIN
    --load_chains

=head2 Loading Human UCSC self-chains:

  perl -w LoadUcscNetData.pl
    --ucsc_dbname ucsc_human_self
    --dbname jh7_compara_blastz_Hg17Self
    --qSpecies hg17
    --tSpecies hg17
    --method_link_type BLASTZ_CHAIN
    --load_chains
    --bin_size 1000000

=head1 INTERNAL METHODS

=cut


use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Compara::GenomicAlign;
#use Bio::EnsEMBL::Utils::Exception qw(verbose);
#verbose("INFO");


my $ucsc_dbname;
my $dbname;

my $tSpecies;
my $tName;
my $qSpecies;
my $qName;
my $reg_conf;
my $start_net_index = 0;
my $method_link_type = "BLASTZ_NET";
my $max_gap_size = 50;
my $matrix_file;
my $show_matrix_to_be_used = 0;
my $bin_size = 1000000;
my $help = 0;
my $check_length = 0;
my $load_chains = 0;
my $filter_duplicate_alignments = 1;

my $usage = "
$0
  [--help]                    this menu
   --ucsc_dbname string       (e.g. ucscMm33Rn3) one of the ucsc source database Bio::EnsEMBL::Registry aliases
   --dbname string            (e.g. compara25) one of the compara destination database Bio::EnsEMBL::Registry aliases
   --tSpecies string          (e.g. mouse) the UCSC target species (i.e. a Bio::EnsEMBL::Registry alias)
                              to which tName refers to
   --qSpecies string          (e.g. Rn3) the UCSC query species (i.e. a Bio::EnsEMBL::Registry alias)
  [--tName string]            (e.g. chr15) one of the chromosome name used by UCSC on their target species (tSpecies)
                              on the base of which alignments will be retrieved
  [--qName string]            (e.g. chrM) one of the chromosome name used by UCSC on their query species (qSpecies)
                              on the base of which alignments will be retrieved
  [--check_length]            check the chromosome length between ucsc and ensembl, then exit
  [--method_link_type string] (e.g. BLASTZ_NET) type of alignment queried (default: BLASTZ_NET)
  [--reg_conf filepath]       the Bio::EnsEMBL::Registry configuration file. If none given, 
                              the one set in ENSEMBL_REGISTRY will be used if defined, if not
                              ~/.ensembl_init will be used.
  [--matrix filepath]         matrix file to be used to score each individual alignment
                              Format should be something like
                              A    C    G    T
                              100 -200  -100 -200
                              -200  100 -200  -100
                              -100 -200  100 -200
                              -200  -100 -200   100
                              O = 2000, E = 50
                              default will choose on the fly the right matrix for the species pair considered.
  [--show_matrix]             Shows the scoring matrix that will be used and exit. Does not start the process
                              loading a compara database. **WARNING** can only be used with the other compulsory 
                              arguments
  [--max_gap_size integer]    default: 50
  [--start_net_index integer] default: 0
  [--load_chains]             Load the chains instead of the nets. default: load the nets
  [--bin_size integer]        Used for loading chains in groups (this can save a lot of memory).
                              default: 1000000
  [--[no]filter_duplicate_alignments]
                              UCSC self-chains are redundant. This option permits to filter out
                              duplicated alignments. Default: filter duplicate alignments

\n";

GetOptions('help' => \$help,
           'ucsc_dbname=s' => \$ucsc_dbname,
           'dbname=s' => \$dbname,
           'method_link_type=s' => \$method_link_type,
           'tSpecies=s' => \$tSpecies,
           'tName=s' => \$tName,
           'qSpecies=s' => \$qSpecies,
           'qName=s' => \$qName,
           'check_length' => \$check_length,
           'reg_conf=s' => \$reg_conf,
           'start_net_index=i' => \$start_net_index,
           'max_gap_size=i' => \$max_gap_size,
           'bin_size=i' => \$bin_size,
           'matrix=s' => \$matrix_file,
           'show_matrix' => \$show_matrix_to_be_used,
           'filter_duplicate_alignments!' => \$filter_duplicate_alignments,
           'load_chains' => \$load_chains);

$| = 1;

if ($help) {
  print $usage;
  exit 0;
}

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->no_version_check(1);
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $primates_matrix_string = "A C G T
 100 -300 -150 -300
-300  100 -300 -150
-150 -300  100 -300
-300 -150 -300  100
O = 400, E = 30
";

my $human_macaca_matrix_string = "A C G T
 100 -200 -100 -200
-200  100 -200 -100
-100 -200  100 -200
-200 -100 -200  100
O = 400, E = 30
";

my $mammals_matrix_string = "A C G T
  91 -114  -31 -123
-114  100 -125  -31
 -31 -125  100 -114
-123  -31 -114   91
O = 400, E = 30
";

my $mammals_vs_other_vertebrates_matrix_string = "A C G T
  91  -90  -25 -100
 -90  100 -100  -25
 -25 -100  100  -90
-100  -25  -90   91
O = 400, E = 30
";

my $tight_matrix_string = "A C G T
 100 -200 -100 -200
-200  100 -200 -100
-100 -200  100 -200
-200 -100 -200  100
O = 2000, E = 50
";

my %undefined_combinaisons;
print STDERR $ucsc_dbname,"\n";
my $ucsc_dbc = Bio::EnsEMBL::Registry->get_DBAdaptor($ucsc_dbname, 'compara')->dbc;

my $gdba = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','GenomeDB')
    or die "Can't get ($dbname,'compara','GenomeDB')\n";
my $dfa = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','DnaFrag')
    or die "Can't get ($dbname,'compara','DnaFrag')\n";
my $gaba = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','GenomicAlignBlock')
    or die " Can't get ($dbname,'compara','GenomicAlignBlock')\n";
my $gaga = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','GenomicAlignGroup')
    or die " Can't get($dbname,'compara','GenomicAlignGroup')\n";
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','MethodLinkSpeciesSet')
    or die " Can't($dbname,'compara','MethodLinkSpeciesSet')\n";

# cache all tSpecies dnafrag from compara
my $tBinomial = get_binomial_name($tSpecies);
my $tTaxon_id = get_taxon_id($tSpecies);
my $tgdb = $gdba->fetch_by_name_assembly($tBinomial) or die " Can't get fetch_by_name_assembly($tBinomial)\n";
my %tdnafrags;
foreach my $df (@{$dfa->fetch_all_by_GenomeDB_region($tgdb)}) {
  $tdnafrags{$df->name} = $df;
}
# Mitonchondrial chr. is called "M" in UCSC and "MT" in EnsEMBL
$tdnafrags{"M"} = $tdnafrags{"MT"} if (defined $tdnafrags{"MT"});

# cache all qSpecies dnafrag from compara
my ($qBinomial, $qTaxon_id, $qgdb, %qdnafrags);
if ($qSpecies eq $tSpecies) {
  $qSpecies = "Self";
  $qBinomial = $tBinomial;
  $qTaxon_id = $tTaxon_id;
  $qgdb = $tgdb;
  %qdnafrags = %tdnafrags;
} else {
  $qBinomial = get_binomial_name($qSpecies);
  $qTaxon_id = get_taxon_id($qSpecies);
  $qgdb = $gdba->fetch_by_name_assembly($qBinomial) or die " Can't get fetch_by_name_assembly($qBinomial)\n";
  foreach my $df (@{$dfa->fetch_all_by_GenomeDB_region($qgdb)}) {
    $qdnafrags{$df->name} = $df;
  }
  # Mitonchondrial chr. is called "M" in UCSC and "MT" in EnsEMBL
  $qdnafrags{"M"} = $qdnafrags{"MT"} if (defined $qdnafrags{"MT"});
}

if ($check_length) {
  check_length(); # Check whether the length of the UCSC and the EnsEMBL chromosome match or not
  exit 0;
}

my $matrix_hash = choose_matrix($matrix_file);
if ($show_matrix_to_be_used) {
  print_matrix($matrix_hash);
  exit 0;
}

# Create and save (if needed) the MethodLinkSpeciesSet
my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
if ($tgdb->dbID == $qgdb->dbID) {
  ## Self alignments
  $mlss->species_set([$tgdb]);
} else {
  ## Pairwise alignments
  $mlss->species_set([$tgdb, $qgdb]);
}
$mlss->method_link_type($method_link_type);
$mlssa->store($mlss); # Sets the dbID if already exists, creates and sets the dbID if not!

my $nb_of_net = 0;
my $nb_of_daf_loaded = 0;

my $net_index = 0; # this counter is used to resume the script if needed

my $simple = 0;
my $direct = 0;
my $gapped = 0;
my $complex = 0;

#####################################################################
##
## Query to fetch all the nets. The nets are the pieces of chain
## which correspond to the best possible chain for every part of
## the query species
##

my $sql;
my $sth;
if ($load_chains) {
  ## This is a hack to fetch chains as they were nets. The rest of the code
  ## uses this data as nets and the result is the loading of all the chains
  my $tables;
    if (defined $tName) {
      $tables = [$tName."_chain$qSpecies"];
    } else {
      $sql = "show tables like \"\%chain$qSpecies\"";
      $tables = $ucsc_dbc->db_handle->selectcol_arrayref($sql);
    }
    foreach my $this_table (@$tables) {
      my $last_net_index = $net_index;
      my $start_limit = 0;
      do {
        $last_net_index = $net_index;
        $sql = "
            SELECT
              1, tName, tStart, tEnd, qName, qSize, qStart, qEnd, qStrand, id
            FROM $this_table
            WHERE
              (tEnd - tStart) * 2 < (qEnd - qStart)
              OR (tEnd - tStart) > 2 * (qEnd - qStart)
            LIMIT $start_limit, $bin_size";
        $start_limit += $bin_size;
        $sth = $ucsc_dbc->prepare($sql);
        fetch_and_load_nets($sth);
      } while ($net_index - $last_net_index == $bin_size);
    }
  
} else {
  my $filter = "";
  if (defined $tName) {
    $filter .= " AND tName = \"$tName\"";
  }
  if (defined $qName) {
    $filter .= " AND qName = \"$qName\"";
  }
  $sql = "
      SELECT
        level, tName, tStart, tEnd, qName, 1, qStart, qEnd, \"+\", chainId
      FROM net$qSpecies
      WHERE type!=\"gap\" $filter
      ORDER BY tStart, chainId";
  $sth = $ucsc_dbc->prepare($sql);
  fetch_and_load_nets($sth);
}
##
#####################################################################



print STDERR "no_mapping = $simple; direct_mapping = $direct; gapped_mapping = $gapped",
    " and complex_mapping (skipped) = $complex\n" if ($direct or $gapped or $complex);
print STDERR "Total number of loaded nets: ", $nb_of_net,"\n";
print STDERR "Total number of loaded GenomicAlignBlocks: ", $nb_of_daf_loaded,"\n";

$sth->finish;

print STDERR "Here is a statistic summary of nucleotides matching not defined in the scoring matrix used\n";
foreach my $key (sort {$a cmp $b} keys %undefined_combinaisons) {
  print STDERR $key," ",$undefined_combinaisons{$key},"\n";
}
print STDERR "\n";

exit();


=head2 fetch_and_load_nets

  Arg[1]     : 
  Example    : 
  Description: 
  Returntype : 

=cut

sub fetch_and_load_nets {
  my ($sth) = @_;

  my $chromosome_specific_chain_tables = get_chromosome_specificity_for_tables(
      $ucsc_dbc, $qSpecies, "chain");
  my $query_golden_path_is_available = check_table($ucsc_dbc, "query_gold");

  $sth->execute();

  my ($n_level,   # level in genomic_align; set to 1 for the chains
      $n_tName,   # name of the target chromosome (e.g. human); used to define the chain
                  # table name if needed
      $n_tStart,  # start position of this net (0-based); used to restrict the chains
      $n_tEnd,    # end position of this net; used to restrict the chains
      $n_qName,   # name of the query chromosome (e.g. cow)
      $n_qSize,   # size of the query chromosome; used to reverse the chain if needed
      $n_qStart,  # start position of this net (0-based, always + strand); used while trying to map
                  # non-toplevel alignments
      $n_qEnd,    # end position of this net (always + strand); used while trying to map
                  # non-toplevel alignments
      $n_qStrand, # strand for the query coordinates (always "+" for the nets); + or -; used to know
                  # when a chain needs to be reversed. The nets are always defined on the forward
                  # strand
      $n_chainId, # chain ID; used to fetch chains; group_id in genomic_align_group
    );
  
  $sth->bind_columns
    (\$n_level, \$n_tName, \$n_tStart, \$n_tEnd, \$n_qName,
    \$n_qSize, \$n_qStart, \$n_qEnd, \$n_qStrand, \$n_chainId);
  
  FETCH_NET: while( $sth->fetch() ) {
    $net_index++;
    next if ($net_index < $start_net_index); # $start_net_index is used to resume the script
#     print STDERR "$net_index: $n_tName ($n_tStart-$n_tEnd) <$n_qStrand> $n_qName ($n_qStart-$n_qEnd)\n";

    $n_qStrand = 1 if ($n_qStrand eq "+");
    $n_qStrand = -1 if ($n_qStrand eq "-");
    $n_tStart++;
    if ($n_qStrand == 1) {
      $n_qStart++;
    } else {
      ## This happen when loading the chains. The nets are always defined on the forward strand...
      my $aux = $n_qStart;
      $n_qStart = $n_qSize - $n_qEnd + 1;
      $n_qEnd = $n_qSize - $aux;
    }
  
    $n_tName =~ s/^chr//;
    $n_qName =~ s/^chr//;
    $n_qName =~ s/^pt0\-//;
  
    ###########
    # Check whether the UCSC chromosome has its counterpart in EnsEMBL. Skip otherwise...
    #
    my $tdnafrag = $tdnafrags{$n_tName};
    my $tdnafrag_length;
    my $t_needs_mapping = 0;
    if (!defined $tdnafrag) {
#       print STDERR "daf not stored because $tBinomial seqname ",$n_tName," not in dnafrag table\n";
      my $slice;
      if ($chromosome_specific_chain_tables) {
        $slice = map_random_chromosome($tSpecies, $n_tName, $n_tStart, $n_tEnd);
      }
      if (!defined($slice)) {
        print STDERR "$net_index (#$n_chainId): daf not stored because $tBinomial seqname ",
            $n_tName, " (", $n_tStart, " - ", $n_tEnd, ") is not in dnafrag table (1)\n";
        next FETCH_NET;
      } elsif (!defined($tdnafrags{$slice->seq_region_name})) {
        print STDERR "$net_index (#$n_chainId): daf not stored because $tBinomial seqname ",
            $n_tName, " [$n_tStart-$n_tEnd] (", $slice->seq_region_name, ") not in dnafrag table (2)\n";
        next FETCH_NET;
      }
      $t_needs_mapping = 1;
      $tdnafrag = $tdnafrags{$slice->seq_region_name};
      $n_tStart = $slice->start; ## This is needed to restrict the chains properly
      $n_tEnd = $slice->end; ## This is needed to restrict the chains properly
#       print STDERR "MAPPING  $tBinomial seqname ",$n_tName, " on ", $slice->seq_region_name,
#           "!!\n";
    } else {
      $tdnafrag_length = $tdnafrag->length();
    }
  
    my $qdnafrag = $qdnafrags{$n_qName};
    my $qdnafrag_length;
    my $q_needs_mapping = 0;
    if (!defined $qdnafrag) {
      ## The alignment might be defined on a non-toplevel seq_region.
      ## The first EnsEMBL cow assembly released included gene_scaffolds for instance
      ## which were built on top of the original scaffolds.
      my ($slice, $coords, $seq_regions) = map_non_toplevel_seqregion($qSpecies,
          $n_qName, $n_qStart, $n_qEnd, 1);
      if ($slice) {
#         print STDERR " => $qBinomial seqname $n_qName ($n_qStart - $n_qEnd) maps on ",
#             join(" -- ", @$seq_regions), "\n";
        foreach my $this_seq_region (@$seq_regions) {
          if (!defined $qdnafrags{$this_seq_region}) {
            print STDERR "$net_index (#$n_chainId): daf not stored because $qBinomial seqname ",
                $n_qName, " [$n_qStart-$n_qEnd] maps on $this_seq_region and it is not in dnafrag table (3)\n";
            next FETCH_NET;
          }
        }
        $qdnafrag_length = $slice->length();
        $q_needs_mapping = "map_non_toplevel_seqregion";
#       } elsif ($chromosome_specific_chain_tables and $qSpecies eq "Self") {
      } else {
        if ($chromosome_specific_chain_tables and $qSpecies eq "Self") {
          $slice = map_random_chromosome($tSpecies, $n_qName, ($n_qStart + 1), $n_qEnd);
        } elsif ($query_golden_path_is_available) {
          $slice = map_random_chromosome($qSpecies, $n_qName, ($n_qStart + 1), $n_qEnd, "query_gold");
        }
        if (!defined($slice)) {
          print STDERR "$net_index (#$n_chainId): daf not stored because $qBinomial seqname ",
              $n_qName, " [", ($n_qStart + 1), "-", $n_qEnd, "] is not in dnafrag table (4)\n";
          next FETCH_NET;
        } elsif (!defined($qdnafrags{$slice->seq_region_name})) {
          print STDERR "$net_index (#$n_chainId): daf not stored because $qBinomial seqname ",
              $n_qName, " [", ($n_qStart + 1), "-", $n_qEnd, "] (", $slice->seq_region_name,
              ") not in dnafrag table (5)\n";
          next FETCH_NET;
        }
        $q_needs_mapping = "map_random_chromosome";
        $qdnafrag = $qdnafrags{$slice->seq_region_name};
      }
    } else {
      $qdnafrag_length = $qdnafrag->length();
    }
    #
    ###########
  
    my ($c_table, $cl_table); # Name of the tables where chain and chain-links are stored
    if ($chromosome_specific_chain_tables) {
      $c_table = "chr" . $n_tName . "_chain" . $qSpecies;
      $cl_table = "chr" .$n_tName . "_chain" . $qSpecies . "Link";
    } else {
      $c_table = "chain" . $qSpecies;
      $cl_table = "chain" . $qSpecies . "Link";
    }
    # as a chainId seems to be specific to a tName, it should be  no need to add an additional constraint
    # on tName in the sql, but for safe keeping let's add it.
    $n_tName = "chr$n_tName" if ($n_tName !~ /^scaffold/ and $n_tName !~ /^ultracontig/);
    $sql = "
      SELECT
        c.score, c.tName, c.tSize, c.tStart, c.tEnd, c.qName, c.qSize, c.qStrand, c.qStart, c.qEnd,
        cl.tStart, cl.tEnd, cl.qStart, cl.qStart+cl.tEnd-cl.tStart as qEnd
      FROM $c_table c, $cl_table cl
      WHERE c.id = cl.chainId and cl.chainId = ? and c.tName = cl.tName and c.tName = \"$n_tName\"";
    my $sth2 = $ucsc_dbc->prepare($sql);
    my $num_rows = $sth2->execute($n_chainId);

    if (!$num_rows or $num_rows == 0) {
      print STDERR "$net_index (#$n_chainId): daf not stored because there are no chains for \"$n_tName\" (X)\n";
      next FETCH_NET;
    }
  
    my ($c_score,     # score for this chain [saved in the FeaturePair but overwritten afterwards]
        $c_tName,     # name of the target (e.g. human) chromosome; used here to set
                      # the seqname for the target seq but overwritten afterwards
        $c_tSize,     # size of the target chromosome; used to check if UCSC and EnsEMBL
                      # chrms. length match
        $c_tStart,    # start of the chain in the target chr. [not used]
        $c_tEnd,      # end of the chain in the target chr. [not used]
        $c_qName,     # name of the query (e.g. mouse) chromosome; used here to set
                      # the seqname for the query seq but overwritten afterwards
        $c_qSize,     # size of the target chromosome; used to check if UCSC and EnsEMBL
                      # chr. length match and to reverse the coordinates when needed
        $c_qStrand,   # strand of the query chain; used to know when the coordinates
                      # need to be reversed
        $c_qStart,    # start of the chain in the query chr. [not used]
        $c_qEnd,      # end of the chain in the query chr. [not used]
        $cl_tStart,   # start of the link (ungapped feature) in the target chr.
        $cl_tEnd,     # end of the link in the target chr.
        $cl_qStart,   # startof the link in the query chr.
        $cl_qEnd);    # end of the link in the query chr.
  
    $sth2->bind_columns(\$c_score,
        \$c_tName,\$c_tSize,\$c_tStart,\$c_tEnd,
        \$c_qName,\$c_qSize,\$c_qStrand,\$c_qStart,\$c_qEnd,
        \$cl_tStart,\$cl_tEnd,\$cl_qStart,\$cl_qEnd);

    my $all_feature_pairs;
    FETCH_CHAIN: while( $sth2->fetch() ) {
      # Checking the chromosome length from UCSC with Ensembl.
      unless (!defined($tdnafrag_length) or $tdnafrag_length == $c_tSize) {
        print STDERR "tSize = $c_tSize for tName = $c_tName and Ensembl has dnafrag",
            " length of $tdnafrag_length\n";
        print STDERR "net_index is $net_index\n";
        exit 2;
      }
      unless (!defined($qdnafrag_length) or $qdnafrag_length == $c_qSize) {
        print STDERR "qSize = $c_qSize for qName = $c_qName and Ensembl has dnafrag",
            " length of $qdnafrag_length\n";
        print STDERR "net_index is $net_index\n";
        exit 3;
      }
      
      $c_qStrand = 1 if ($c_qStrand eq "+");
      $c_qStrand = -1 if ($c_qStrand eq "-");
      $c_tStart++;
      $c_qStart++;
      $cl_tStart++;
      $cl_qStart++;
      $c_tName =~ s/^chr//;
      $c_qName =~ s/^chr//;
      $c_qName =~ s/^pt0\-//;
      
  
      if ($c_qStrand < 0) {
        my $length = $cl_qEnd - $cl_qStart;
        $cl_qStart = $c_qSize - $cl_qEnd + 1;
        $cl_qEnd = $cl_qStart + $length;
      }
  
      if ($t_needs_mapping) {
        my $slice = map_random_chromosome($tSpecies, $c_tName, $cl_tStart, $cl_tEnd);
        if (!defined($slice)) {
          print STDERR "$net_index (#$n_chainId): daf not stored because $tBinomial seqname ",
              $c_tName, " [$cl_tStart-$cl_tEnd] is not in dnafrag table (7)\n";
          next FETCH_CHAIN;
        } elsif (!defined($tdnafrags{$slice->seq_region_name})) {
          print STDERR "$net_index (#$n_chainId): daf not stored because $tBinomial seqname ",
              $c_tName, " [$cl_tStart-$cl_tEnd] (", $slice->seq_region_name, ") not in dnafrag table (8)\n";
          next FETCH_CHAIN;
        }
        if ($cl_tEnd - $cl_tStart != $slice->end - $slice->start) {
          print STDERR "$net_index (#$n_chainId): daf not stored because length of $c_tName [$cl_tStart-$cl_tEnd] ",
              "does not match => ", $slice->seq_region_name, " [", $slice->start, "-", $slice->end, "] (9)\n";
          next FETCH_CHAIN;
        }
        $c_tName = $slice->seq_region_name;
        $cl_tStart = $slice->start;
        $cl_tEnd = $slice->end;
      }

      if ($q_needs_mapping eq "map_non_toplevel_seqregion") {
        my ($slice, $coords, $seq_regions) = map_non_toplevel_seqregion($qSpecies,
          $c_qName, $cl_qStart, $cl_qEnd, $c_qStrand);
        my %seq_regions;
#         print STDERR "$qBinomial $n_qName -> ", join(" - ", @seq_regions), "\n";
        foreach my $seq_region (@$seq_regions) {
          $seq_regions{$seq_region} = 1;
          $qdnafrag = $qdnafrags{$seq_region};
          if (!defined $qdnafrag) {
            print STDERR "$net_index (#$n_chainId): daf not stored because $qBinomial seqname ",
                $n_qName," not in dnafrag table, so not in core (10)\n";
            next FETCH_CHAIN;
          }
        }
        if (scalar(@$coords) == 1) {
          $direct++;
        } else {
          if (scalar(keys %seq_regions) == 1) {
            $gapped++;
#            print STDERR "net_index: $net_index, tStart: $n_tStart, chainId: $n_chainId\n",
#                " $c_qName($seq_regions[0]), $cl_qStart, $cl_qEnd, $c_qStrand\n";
          } else {
            $complex++;
            ## Not supported at the moment!!!
            print STDERR "$net_index (#$n_chainId): daf not stored because $qBinomial seqname ",
                $n_qName," maps on several seq_regions. (11)\n";
            next FETCH_CHAIN;
          }
        }
        my $start = $cl_tStart;
        foreach my $coord (@$coords) {
          if ($coord->isa("Bio::EnsEMBL::Mapper::Coordinate")) {
            my $this_feature_pair = new  Bio::EnsEMBL::FeaturePair(
                -seqname  => $c_tName,
                -start    => $start,
                -end      => $start + $coord->length - 1,
                -strand   => 1,
                -hseqname => shift @$seq_regions,
                -hstart   => $coord->start,
                -hend     => $coord->end,
                -hstrand  => $coord->strand,
                -score    => $c_score);
            push(@$all_feature_pairs, $this_feature_pair);
          }
          $start += $coord->length;
        }
      } else {
        if ($q_needs_mapping eq "map_random_chromosome") {
          my $slice;
          if ($qSpecies eq "Self") {
            $slice = map_random_chromosome($tSpecies, $c_qName, $cl_qStart, $cl_qEnd);
          } else {
            $slice = map_random_chromosome($qSpecies, $c_qName, $cl_qStart, $cl_qEnd, "query_gold");
          }
          if (!defined($slice)) {
            print STDERR "$net_index (#$n_chainId): daf not stored because $qBinomial seqname ",
                $c_qName, " (", ($c_qStart), " - ", $c_qEnd, ") is not in dnafrag table (12)\n";
            next FETCH_CHAIN;
          } elsif (!defined($qdnafrags{$slice->seq_region_name})) {
            print STDERR "$net_index (#$n_chainId): daf not stored because $qBinomial seqname ",
                $c_qName, " (", $slice->seq_region_name, ") not in dnafrag table (13)\n";
            next FETCH_CHAIN;
          }
          $c_qName = $slice->seq_region_name;
          $cl_qStart = $slice->start;
          $cl_qEnd = $slice->end;
        }

        $simple++;
        my $this_feature_pair = new  Bio::EnsEMBL::FeaturePair(
            -seqname  => $c_tName,
            -start    => $cl_tStart,
            -end      => $cl_tEnd,
            -strand   => 1,
            -hseqname  => $c_qName,
            -hstart   => $cl_qStart,
            -hend     => $cl_qEnd,
            -hstrand  => $c_qStrand,
            -score    => $c_score);
        push(@$all_feature_pairs, $this_feature_pair);
      }
    } ### End while loop (FETCH_CHAIN)
  
    my $dna_align_features = get_DnaAlignFeatures_from_FeaturePairs(
        $all_feature_pairs, $n_chainId, (($n_level+1)/2));

    my @new_dafs;
    while (my $daf = shift @$dna_align_features) {
      my $daf = $daf->restrict_between_positions($n_tStart,$n_tEnd,"SEQ");
      unless (defined $daf) {
        print STDERR "DnaDnaAlignFeature lost during restriction...\n" if ($load_chains);
        next;
      }
      push @new_dafs, $daf;
    }
    next unless (scalar @new_dafs);
#     print STDERR "Loading ",scalar @new_dafs,"...\n";
    
    foreach my $daf (@new_dafs) {
      $nb_of_daf_loaded += save_daf_as_genomic_align_block($daf);
    }
    $nb_of_net++;
  }
}


=head2 get_binomial_name

  Arg[1]     : string $species_name
  Example    : $human_binomial_name = get_binomial_name("human");
  Description: This method get the binomial name from the core database.
               It takes a Registry alias as an input and return the
               binomial name for that species.
  Returntype : string

=cut

sub get_binomial_name {
  my ($species) = @_;
  my $binomial_name;

  my $meta_container_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'MetaContainer');
  if (!defined($meta_container_adaptor)) {
    die("Cannot get the MetaContainerAdaptor for species <$species>\n");
  }
  $binomial_name = $meta_container_adaptor->get_Species->binomial;
  if (!$binomial_name) {
    die("Cannot get the binomial name for species <$species>\n");
  }

  return $binomial_name;
}


=head2 get_taxon_id

  Arg[1]     : string $species_name
  Example    : $human_taxon_id = get_taxon_id("human");
  Description: This method get the taxon ID from the core database.
               It takes a Registry alias as an input and return the
               taxon ID for that species.
  Returntype : int

=cut

sub get_taxon_id {
  my ($species) = @_;
  my $taxon_id;

  my $meta_container_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'MetaContainer');
  if (!defined($meta_container_adaptor)) {
    die("Cannot get the MetaContainerAdaptor for species <$species>\n");
  }
  $taxon_id = $meta_container_adaptor->get_taxonomy_id;
  if (!$taxon_id) {
    die("Cannot get the taxon ID for species <$species>\n");
  }

  return $taxon_id;
}


=head2 get_chromosome_specificity_for_tables

  Arg[1]     : Bio::EnsEMBL::DBSQL::DBConnection $ucsc_compara_dbc
  Arg[2]     : string $species_name
  Arg[3]     : string $type ("chain" or "net")
  Example    : $chromosome_specific_chain_table =
                 get_chromosome_specificity_for_tables($ucsc_compara_dbc,
                 "hg17", "chain");
  Description: UCSC database may contain a pair of tables for all the
               chromosomes or a pair per chromosome depending on the species.
               This method tests whether the tables are chromosome
               specific or not
  Returntype : boolean

=cut

sub get_chromosome_specificity_for_tables {
  my ($ucsc_dbc, $species, $type) = @_;
  my $chromosome_specific_chain_tables = 1;
  
  $type = "chain" unless (defined($type) and $type eq "net");
  
  my $sql = "show tables like '$type$species\%'";
  $sth = $ucsc_dbc->prepare($sql);
  $sth->execute;
  
  my ($table_name);
  
  $sth->bind_columns(\$table_name);
  
  my $table_count = 0;
  
  while( $sth->fetch() ) {
    if ($table_name eq "$type$species") {
      $table_count++;
    }
    if ($table_name eq $type.$species."Link") {
      $table_count++;
    }
  }
  $sth->finish;

  $chromosome_specific_chain_tables = 0 if ($table_count == 2);
  
  return $chromosome_specific_chain_tables;
}


=head2 check_table

  Arg[1]     : Bio::EnsEMBL::DBSQL::DBConnection $ucsc_compara_dbc
  Arg[2]     : string $table_name
  Example    : $table_exists = check_table($ucsc_compara_dbc, "query_gold");
  Description: Check whether a table called $table_name exists in the
               database
  Returntype : boolean

=cut

sub check_table {
  my ($ucsc_dbc, $table_name) = @_;

  my $sql = "show tables like '$table_name'";
  $sth = $ucsc_dbc->prepare($sql);
  $sth->execute;

  my ($temp);

  $sth->bind_columns(\$temp);

  my $table_count = 0;

  while( $sth->fetch() ) {
    $table_count++;
  }
  $sth->finish;

  return $table_count;
}


=head2 map_random_chromosome

  Arg[1]     : string $species_name
  Arg[2]     : string $seq_region_name
  Arg[3]     : int $start (inclusive coordinates)
  Arg[4]     : int $end (inclusive coordinates)
  Arg[5]     : (optional) string table_name
  Example    :
  Description: This method tries to match the EnsEMBL Slice corresponding
               to the piece of UCSC random chromosome. The UCSC random
               chromosomes are a hack used to refer to non-chromosome level
               sequences in the UCSC genome DB.
  Returntype : Bio::EnsEMBL::Slice object

=cut

my $hap_mappings;

sub map_random_chromosome {
  my ($species_name, $seq_region_name, $start, $end, $table_name) = @_;
  my $slices;

  my $random_sql = "SELECT chrom, chromStart, chromEnd, frag, fragStart, fragEnd, strand FROM ".
    ($table_name?$table_name:"chr${seq_region_name}_gold").
    " WHERE chrom = ? and chromStart <= ? and chromEnd >= ? ORDER BY chromStart";
  my $random_sth = $ucsc_dbc->prepare($random_sql);
  $random_sth->execute("chr${seq_region_name}", $end, $start - 1);
  my $all_data = $random_sth->fetchall_arrayref;

  my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species_name, "core", "Slice");

  if ($seq_region_name =~ /_hap/) {
    if (!$hap_mappings) {
      my @hap_slices = grep {$_->get_all_Attributes("non_ref")->[0]}
          @{$slice_adaptor->fetch_all("chromosome", undef, 1)};
      foreach my $this_hap_slice ( @hap_slices ) {
        my $projections = $this_hap_slice->project("clone");
        foreach my $this_p ( @$projections ) {
          if (defined($hap_mappings->{$this_p->to_Slice->seq_region_name})) {
            print "ALREADY DEFINED ", $this_p->to_Slice->seq_region_name, "\n";
          } else {
            $hap_mappings->{$this_p->to_Slice->seq_region_name}->{projection} = $this_p;
            $hap_mappings->{$this_p->to_Slice->seq_region_name}->{slice} = $this_hap_slice;
          }
        }
      }
    }
    my $can_be_mapped = 1;
    my $slice;
    foreach my $data (@$all_data) {
      my $chrom_start = $data->[1];
      my $chrom_end = $data->[2];
      my $frag_name = $data->[3];
      my $frag_start = $data->[4];
      my $frag_end = $data->[5];
      my $frag_strand = ($data->[6] eq "-")?-1:1;
      ## Check coordinates
      if ($hap_mappings->{$frag_name}) {
        my $proj = $hap_mappings->{$frag_name}->{projection};
        if (!defined($slice)) {
          $slice = $hap_mappings->{$frag_name}->{slice};
        } elsif ($slice != $hap_mappings->{$frag_name}->{slice}) {
          $can_be_mapped = 0;
          last;
        }
        if (($proj->from_start != $chrom_start + 1)
            or ($proj->from_end != $chrom_end)
            or ($proj->to_Slice->seq_region_name ne $frag_name)
            or ($proj->to_Slice->start != $frag_start + 1)
            or ($proj->to_Slice->end != $frag_end)
            or ($proj->to_Slice->strand != $frag_strand)) {
          $can_be_mapped = 0;
          last;
        }
      }
    }
    return undef if (!$can_be_mapped);
    return $slice->sub_Slice($start, $end);

  } else {
    ## Get mapping information from goldenpath table
    foreach my $data (@$all_data) {
      my $chrom_start = $data->[1];
      my $chrom_end = $data->[2];
      my $frag_name = $data->[3];
      my $frag_start = $data->[4];
      my $frag_end = $data->[5];
      my $frag_strand = $data->[6];

      my ($slice_start, $slice_end, $slice_strand);
      $slice_start = $start - $chrom_start + $frag_start;
      $slice_end = $end - $chrom_start + $frag_start;
      if ($frag_strand ne "-") {
        $slice_strand = 1;
      } else {
        $slice_strand = -1;
      }
    
      my $slice = $slice_adaptor->fetch_by_region(undef, $frag_name, $slice_start, $slice_end, $slice_strand);
      if (!defined($slice)) {
        ## Fake slice. Used to give a more useful warning message!
        $slice = new Bio::EnsEMBL::Slice(
              -seq_region_name => "--".$frag_name,
              -start => $frag_start,
              -end => $frag_end,
              -strand => ($frag_strand eq "+")?1:-1,
              -coord_system => new Bio::EnsEMBL::CoordSystem(-name => "unknown", -rank => 100),
          );
        print STDERR "Cannot find the slice (", $slice->name, ")!\n";
        return $slice;
      }
      push(@$slices, $slice);
    }

  }


  my $projections = [];
  foreach my $this_slice (@$slices) {
    push(@$projections, @{$this_slice->project("toplevel")});
  }
  if (!@$projections) {
    return undef;
  } elsif (@$projections > 1) {

    ## This may happen if a chain span a gap in the assembly. We try to rescue the alignment
    ## if the gap corresponds to a gap in the clone sequence.
    my $gapped_seq_region_name;
    my $gapped_start;
    my $gapped_end;
    my $gapped_strand;
    foreach my $this_projection (@$projections) {
      if (!defined($gapped_seq_region_name)) {
        $gapped_seq_region_name = $this_projection->to_Slice->seq_region_name;
        $gapped_start = $this_projection->to_Slice->start;
        $gapped_end = $this_projection->to_Slice->end;
        $gapped_strand = $this_projection->to_Slice->strand;
      } else {
        if ($gapped_seq_region_name ne $this_projection->to_Slice->seq_region_name) {
          ## A clone might be on both the haplotype and the ref sequence. Keep the haplotype
          my $name1 = $gapped_seq_region_name;
          my $name2 = $this_projection->to_Slice->seq_region_name;
          if ($name1 =~ /^c${name2}_/) {
            $gapped_seq_region_name = $name1;
          } elsif ($name2 =~ /^c${name1}_/) {
            $gapped_seq_region_name = $name2;
          } else {
            return undef;
          }
          if ($seq_region_name !~ /_hap/) {
            ## Use the reference sequence
            $gapped_seq_region_name =~ s/^c//;
            $gapped_seq_region_name =~ s/_.//;
          }
        } elsif ($gapped_strand != $this_projection->to_Slice->strand) {
          return undef;
        }
        $gapped_start = $this_projection->to_Slice->start
            if ($gapped_start > $this_projection->to_Slice->start);
        $gapped_end = $this_projection->to_Slice->end
            if ($gapped_end < $this_projection->to_Slice->end);
      }
    }
    my $slice = $slice_adaptor->fetch_by_region(undef,
        $gapped_seq_region_name, $gapped_start, $gapped_end, $gapped_strand);
    return $slice;
  }

  return $projections->[0]->to_Slice;
}


=head2 map_non_toplevel_seqregion

  Arg[1]     : string $species_name
  Arg[2]     : string $seq_region_name
  Arg[3]     : int $start
  Arg[4]     : int $end
  Arg[4]     : int $strand
  Example    :
  Description: This method tries to map UCSC coordinates on toplevel
               EnsEMBL seq_regions. This is needed when EnsEMBL provides
               an extra level of assembly like in the case of the first
               release of the cow genome.
  Returntype : listref of Bio::EnsEMBL::Coordinate or Bio::EnsEMBL::Gap
               objects and a listref of strings

=cut

sub map_non_toplevel_seqregion {
  my ($species_name, $seq_region_name, $start, $end, $strand) = @_;

  my $coord_system_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
      $species_name, "core", "CoordSystem");
  return (undef, undef, undef) if (!$coord_system_adaptor);

  my $binomial = get_binomial_name($species_name);

  my $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species_name, "core", "Slice");
  my $slice;
  if ($seq_region_name =~ /^SCAFFOLD/i) {
    $slice = $slice_adaptor->fetch_by_region("scaffold", $seq_region_name);
  }
  if (!$slice and $binomial eq "Bos taurus" and $seq_region_name =~ /^SCAFFOLD(\d+)/i) {
    $slice = $slice_adaptor->fetch_by_region("scaffold", "ChrUn.$1");
  }
  if (!$slice and $binomial eq "Bos taurus" and $seq_region_name eq "X") {
    $slice = $slice_adaptor->fetch_by_region("chromosome", "30");
  }
  return (undef, undef, undef) if (!$slice);

  my $other_coord_system = $slice->coord_system;

  my $assembly_mapper_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
      $species_name, "core", "AssemblyMapper");
  my $toplevel_coord_system = $coord_system_adaptor->fetch_by_name("toplevel");
  my $assembly_mapper = $assembly_mapper_adaptor->fetch_by_CoordSystems(
      $other_coord_system, $toplevel_coord_system);

  my @coords = $assembly_mapper->map($slice->seq_region_name,
      $start, $end, $strand, $other_coord_system);
  my @seq_regions = $assembly_mapper->list_seq_regions($slice->seq_region_name,
      $start, $end, $other_coord_system);

  return ($slice, \@coords, \@seq_regions);
}


=head2 get_DnaAlignFeatures_from_FeaturePairs

  Arg[1]     : arrayref of Bio::EnsEMBL::FeaturePair objects
  Example    :
  Description: transform a set of Bio::EnsEMBL::FeaturePair objects
               into a set of Bio::EnsEMBL::DnaDnaAlignFeature objects
               made of compatible Bio::EnsEMBL::FeaturePair objects
  Returntype : arrayref of Bio::EnsEMBL::DnaDnaAlignFeature objects

=cut

sub get_DnaAlignFeatures_from_FeaturePairs {
  my ($all_feature_pairs, $group_id, $level) = @_;
  my $dna_align_features;

  my $these_feature_pairs = [];
  my ($previous_t_seqname, $previous_t_end, $previous_t_strand,
      $previous_q_seqname, $previous_q_start, $previous_q_end,
      $previous_q_strand);
  foreach my $this_feature_pair (@$all_feature_pairs) {
    my $t_seqname = $this_feature_pair->seqname;
    my $t_start = $this_feature_pair->start;
    my $t_end = $this_feature_pair->end;
    my $t_strand = $this_feature_pair->strand;
    my $q_seqname = $this_feature_pair->hseqname;
    my $q_start = $this_feature_pair->hstart;
    my $q_end = $this_feature_pair->hend;
    my $q_strand = $this_feature_pair->hstrand;
    
    unless (defined $previous_t_end && defined $previous_q_end) {
      $previous_t_seqname = $t_seqname;
      $previous_t_end = $t_end;
      $previous_t_strand = $t_strand;
      $previous_q_seqname = $q_seqname;
      $previous_q_start = $q_start;
      $previous_q_end = $q_end;
      $previous_q_strand = $q_strand;
      push @$these_feature_pairs, $this_feature_pair;
      next;
    }

    if (
      # if target seqname changed (may happen because of the mapping)
      ($t_seqname ne $previous_t_seqname) or

      # if query seqname changed (may happen because of the mapping)
      ($q_seqname ne $previous_q_seqname) or

      # if target strand changed
      ($t_strand != $previous_t_strand) or

      # if query strand changed
      ($q_strand ne $previous_q_strand) or

      # if there are insertions in both sequences (non-equivalent regions)
      (($t_start - $previous_t_end > 1) && 
      (($q_strand > 0 && $q_start - $previous_q_end > 1) ||
      ($q_strand < 0 && $previous_q_start - $q_end > 1))) or

      # if gap is larger that $max_gap_size in target seq
      ($t_start - $previous_t_end > $max_gap_size) or

      # if gap is larger that $max_gap_size in query seq
      (($q_strand > 0 && $q_start - $previous_q_end > $max_gap_size) ||
      ($q_strand < 0 && $previous_q_start - $q_end > $max_gap_size))
        ) {
      my $this_dna_align_feature = new Bio::EnsEMBL::DnaDnaAlignFeature(
          -features => \@$these_feature_pairs);
      $these_feature_pairs = [];
      $this_dna_align_feature->group_id($group_id);
      $this_dna_align_feature->level_id($level);
      push @$dna_align_features, $this_dna_align_feature;
    }
    $previous_t_seqname = $t_seqname;
    $previous_t_end = $t_end;
    $previous_t_strand = $t_strand;
    $previous_q_seqname = $q_seqname;
    $previous_q_start = $q_start;
    $previous_q_end = $q_end;
    $previous_q_strand = $q_strand;
    push @$these_feature_pairs, $this_feature_pair;
  }
  if (@$these_feature_pairs) {
    my $this_dna_align_feature = new Bio::EnsEMBL::DnaDnaAlignFeature(
        -features => \@$these_feature_pairs);
    $these_feature_pairs = [];
    $this_dna_align_feature->group_id($group_id);
    $this_dna_align_feature->level_id($level);
    push @$dna_align_features, $this_dna_align_feature;
  }

  return $dna_align_features;
}


=head2 save_daf_as_genomic_align_block

  Arg[1]     : Bio::EnsEMBL::DnaDnaAlignFeature $daf
  Example    : save_daf_as_genomic_align_block($daf)
  Description: 
  Returntype : int (1 if loaded, 0 otherwise)

=cut

sub save_daf_as_genomic_align_block {
  my ($daf) = @_;
    
  # Get cigar_lines and length of the alignment from the daf object
  my ($tcigar_line, $qcigar_line, $length) = parse_daf_cigar_line($daf);

  # Create GenomicAlign for target sequence
  my $tga = new Bio::EnsEMBL::Compara::GenomicAlign;
  $tga->dnafrag($tdnafrags{$daf->seqname});
  $tga->dnafrag_start($daf->start);
  $tga->dnafrag_end($daf->end);
  $tga->dnafrag_strand($daf->strand);
  $tga->cigar_line($tcigar_line);
  $tga->level_id($daf->level_id);

  # Create GenomicAlign for query sequence
  my $qga = new Bio::EnsEMBL::Compara::GenomicAlign;
  $qga->dnafrag($qdnafrags{$daf->hseqname});
  $qga->dnafrag_start($daf->hstart);
  $qga->dnafrag_end($daf->hend);
  $qga->dnafrag_strand($daf->hstrand);
  $qga->cigar_line($qcigar_line);
  $qga->level_id($daf->level_id);

  # Self-chains. Every chain appears twice (except palindromic sequences) in UCSC...
  if ($tga->dnafrag->genome_db->dbID == $qga->dnafrag->genome_db->dbID) {
    ## Skip this alignment if 
    if ($filter_duplicate_alignments and
        (
          ## ... first DnaFragID > second DnaFragID
          ($tga->dnafrag->dbID > $qga->dnafrag->dbID) or
          ## ... same DnaFrag and first block appears after the second one
          ($tga->dnafrag->dbID == $qga->dnafrag->dbID and $tga->dnafrag_start > $qga->dnafrag_start)
        )) {
      return 0;
    }
  }

  # Create the GenomicAlignBlock
  my $gab = new Bio::EnsEMBL::Compara::GenomicAlignBlock;
  $gab->method_link_species_set($mlss);

  # Re-score the GenomicAlignBlock (previous score was for the whole net)
  my ($score, $percent_id) = score_and_identity($qga->aligned_sequence,
      $tga->aligned_sequence, $matrix_hash);
  $gab->score($score);
  $gab->perc_id($percent_id);
  $gab->length($length);
  $gab->genomic_align_array([$tga, $qga]);
  $gab->group_id($daf->group_id);

  $gaba->store($gab); # This stores the Bio::EnsEMBL::Compara::GenomicAlign objects

  return 1;
}

=head2 parse_daf_cigar_line

  Arg[1]     : 
  Example    : 
  Description: 
  Returntype : 

=cut

sub parse_daf_cigar_line {
  my ($daf) = @_;
  my ($cigar_line, $hcigar_line, $length);

  my @pieces = split(/(\d*[DIMG])/, $daf->cigar_string);

  my $counter = 0;
  my $hcounter = 0;
  foreach my $piece ( @pieces ) {
    next if ($piece !~ /^(\d*)([MDI])$/);
    
    my $num = ($1 or 1);
    my $type = $2;
    
    if( $type eq "M" ) {
      $counter += $num;
      $hcounter += $num;
      
    } elsif( $type eq "D" ) {
      $cigar_line .= (($counter == 1) ? "" : $counter)."M";
      $counter = 0;
      $cigar_line .= (($num == 1) ? "" : $num)."D";
      $hcounter += $num;
      
    } elsif( $type eq "I" ) {
      $counter += $num;
      $hcigar_line .= (($hcounter == 1) ? "" : $hcounter)."M";
      $hcounter = 0;
      $hcigar_line .= (($num == 1) ? "" : $num)."D";
    }
    $length += $num;
  }
  $cigar_line .= (($counter == 1) ? "" : $counter)."M"
    if ($counter);
  $hcigar_line .= (($hcounter == 1) ? "" : $hcounter)."M"
    if ($hcounter);
  
  return ($cigar_line, $hcigar_line, $length);
}


=head2 choose_matrix

  Arg[1]     : string $matrix_filename
  Example    : $matrix_hash = choose_matrix();
  Example    : $matrix_hash = choose_matrix("this_matrix.txt");
  Description: reads the matrix from the file provided or get the right matrix
               depending on the pair of species.
  Returntype : ref. to a hash

=cut

sub choose_matrix {
  my ($matrix_file) = @_;
  my $matrix_hash;

  if ($matrix_file) {
    my $matrix_string = "";
    open M, $matrix_file ||
      die "Can not open $matrix_file file\n";
    while (<M>) {
      next if (/^\s*$/);
      $matrix_string .= $_;
    }
    close M;
    $matrix_hash = get_matrix_hash($matrix_string);
    print STDERR "Using customed scoring matrix from $matrix_file file\n";
#     print STDERR "\n$matrix_string\n";
  
  } elsif ( grep(/^$tTaxon_id$/, (9606, 9554)) &&
      grep(/^$qTaxon_id$/, (9606, 9554)) ) {
    $matrix_hash = get_matrix_hash($human_macaca_matrix_string);
    print STDERR "Using human-macaque scoring matrix\n";
#     print STDERR "\n$human_macaca_matrix_string\n";
  
  } elsif ( grep(/^$tTaxon_id$/, (9606, 9598)) &&
      grep(/^$qTaxon_id$/, (9606, 9598)) ) {
    $matrix_hash = get_matrix_hash($primates_matrix_string);
    print STDERR "Using primates scoring matrix\n";
#     print STDERR "\n$primates_matrix_string\n";
  
  } elsif ( grep(/^$tTaxon_id$/, (9606, 10090, 10116, 9598, 9615, 9913)) &&
            grep(/^$qTaxon_id$/, (9606, 10090, 10116, 9598, 9615, 9913)) ) {
    $matrix_hash = get_matrix_hash($mammals_matrix_string);
    print STDERR "Using mammals scoring matrix\n";
#     print STDERR "\n$mammals_matrix_string\n";
  
  } elsif ( (grep(/^$tTaxon_id$/, (9606, 10090, 10116, 9598, 9615, 9913, 9031)) &&
            grep(/^$qTaxon_id$/, (31033, 7955, 9031, 99883, 8364, 8090)))
            ||
            (grep(/^$qTaxon_id$/, (9606, 10090, 10116, 9598, 9615, 9913, 9031)) &&
            grep(/^$tTaxon_id$/, (31033, 7955, 9031, 99883, 8364, 8090)))) {
    $matrix_hash = get_matrix_hash($mammals_vs_other_vertebrates_matrix_string);
    print STDERR "Using mammals_vs_other_vertebrates scoring matrix\n";
#     print STDERR "\n$mammals_vs_other_vertebrates_matrix_string\n";
  
  } else {
    die "taxon_id undefined or matrix not set up for this pair of species $tTaxon_id, $qTaxon_id)\n";
  }

  return $matrix_hash;
}

=head2 get_matrix_hash

  Arg[1]     : string $matrix_string
  Example    : $matrix_hash = get_matrix_hash($matrix_string);
  Description: transform the matrix string into a hash
  Returntype : ref. to a hash

=cut

sub get_matrix_hash {
  my ($matrix_string) = @_;
  
  my %matrix_hash;

  my @lines = split /\n/, $matrix_string;
  my @letters = split /\s+/, shift @lines;

  foreach my $letter (@letters) {
    my $line = shift @lines;
    $line =~ s/^\s+//;
    $line =~ s/\s+$//;
    my @penalties = split /\s+/, $line;
    die "Size of letters array and penalties array are different\n"
        unless (scalar @letters == scalar @penalties);
    for (my $i=0; $i < scalar @letters; $i++) {
      $matrix_hash{uc $letter}{uc $letters[$i]} = $penalties[$i];
      $matrix_hash{uc $letters[$i]}{uc $letter} = $penalties[$i];
    }
  }
  while (my $line = shift @lines) {
    if ($line =~ /^\s*O\s*=\s*(\d+)\s*,\s*E\s*=\s*(\d+)\s*$/) {
      my $gap_opening_penalty = $1;
      my $gap_extension_penalty = $2;

      $gap_opening_penalty *= -1 if ($gap_opening_penalty > 0);
      $matrix_hash{'gap_opening_penalty'} = $gap_opening_penalty;

      $gap_extension_penalty *= -1 if ($gap_extension_penalty > 0);
      $matrix_hash{'gap_extension_penalty'} = $gap_extension_penalty;
    }
  }

  return \%matrix_hash;
}


=head2 print_matrix

  Arg[1]     : hashref $matix_hash 
  Example    : print_matrix($matrix_hash)
  Description: print the weight matrix to the STDERR
  Returntype : -none-

=cut

sub print_matrix {
  my ($matrix_hash) = @_;

  print STDERR "Here is the matrix hash structure\n";
  foreach my $key1 (sort {$a cmp $b} keys %{$matrix_hash}) {
    if ($key1 =~ /[ACGT]+/) {
      print STDERR "$key1 :";
      foreach my $key2 (sort {$a cmp $b} keys %{$matrix_hash->{$key1}}) {
        printf STDERR "   $key2 %5d",$matrix_hash->{$key1}{$key2};
      }
      print STDERR "\n";
    } else {
      print STDERR $key1," : ",$matrix_hash->{$key1},"\n";
    }
  }
  print STDERR "\n";
}


=head2 score_and_identity

  Arg[1]     : 
  Example    : 
  Description: 
  Returntype : 

=cut

sub score_and_identity {
  my ($qy_seq, $tg_seq, $matrix_hash) = @_;

  my $length = length($qy_seq);

  unless (length($tg_seq) == $length) {
    warn "qy sequence length ($length bp) and tg sequence length (".length($tg_seq)." bp)".
        " should be identical\nExit 1\n";
    exit 1;
  }

  my @qy_seq_array = split //, $qy_seq;
  my @tg_seq_array = split //, $tg_seq;

  my $score = 0;
  my $number_identity = 0;
  my $opened_gap = 0;
  for (my $i=0; $i < $length; $i++) {
    if ($qy_seq_array[$i] eq "-" || $tg_seq_array[$i] eq "-") {
      if ($opened_gap) {
        $score += $matrix_hash->{'gap_extension_penalty'};
      } else {
        $score += $matrix_hash->{'gap_opening_penalty'};
        $opened_gap = 1;
      }
    } else {
      # maybe check for N letter here
      if (uc $qy_seq_array[$i] eq uc $tg_seq_array[$i]) {
        $number_identity++;
      }
      unless (defined $matrix_hash->{uc $qy_seq_array[$i]}{uc $tg_seq_array[$i]}) {
        unless (defined $undefined_combinaisons{uc $qy_seq_array[$i] . ":" . uc $tg_seq_array[$i]}) {
          $undefined_combinaisons{uc $qy_seq_array[$i] . ":" . uc $tg_seq_array[$i]} = 1;
        } else {
          $undefined_combinaisons{uc $qy_seq_array[$i] . ":" . uc $tg_seq_array[$i]}++;
        }
#        print STDERR uc $qy_seq_array[$i],":",uc $tg_seq_array[$i]," combination not defined in the matrix\n";
      } else {
        $score += $matrix_hash->{uc $qy_seq_array[$i]}{uc $tg_seq_array[$i]};
      }
      $opened_gap = 0;
    }
  }

  return ($score, int($number_identity/$length*100));
}


=head2 check_length

  Arg[1]     : 
  Example    : 
  Description: 
  Returntype : 

=cut

sub check_length {

  my $sql = "show tables like '"."%"."chain$qSpecies'";
  my $sth = $ucsc_dbc->prepare($sql);
  $sth->execute();

  my ($table);
  $sth->bind_columns(\$table);
  
  my (%tNames,%qNames);
  
  while( $sth->fetch() ) {
    $sql = "select tName,tSize from $table group by tName,tSize";
    
    my $sth2 = $ucsc_dbc->prepare($sql);
    $sth2->execute();
    
    my ($tName,$tSize);
    
    $sth2->bind_columns(\$tName,\$tSize);

    while( $sth2->fetch() ) {
      $tName =~ s/^chr//;
      $tNames{$tName} = $tSize;
    }
    $sth2->finish;

    $sql = "select qName,qSize from $table group by qName,qSize";

    $sth2 = $ucsc_dbc->prepare($sql);
    $sth2->execute();

    my ($qName,$qSize);
    
    $sth2->bind_columns(\$qName,\$qSize);

    while( $sth2->fetch() ) {
      $qName =~ s/^chr//;
      $qNames{$qName} = $qSize;
    }
    $sth2->finish;
  }

  $sth->finish;

  # Checking the chromosome length from UCSC with Ensembl.
  foreach my $tName (keys %tNames) {
    my $tdnafrag = $tdnafrags{$tName};
    next unless (defined $tdnafrag);
    unless ($tdnafrag->length == $tNames{$tName}) {
      print STDERR "tSize = " . $tNames{$tName} ." for tName = $tName and Ensembl has dnafrag length of ",$tdnafrag->length . "\n";
    }
  }
  # Checking the chromosome length from UCSC with Ensembl.
  foreach my $qName (keys %qNames) {
    my $qdnafrag = $qdnafrags{$qName};
    next unless (defined $qdnafrag);
    unless ($qdnafrag->length == $qNames{$qName}) {
      print STDERR "qSize = " . $qNames{$qName} ." for qName = $qName and Ensembl has dnafrag length of ",$qdnafrag->length . "\n";
    }
  }
}

