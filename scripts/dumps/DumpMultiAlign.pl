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
of its aliases. Uses "Multi" by default.

=back

=head2 SPECIFYING THE QUERY SLICE

=over

=item B<[--species species]>

Query species.

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

The type of alignment. This can be BLASTZ_NET, TRANSLATED_BLAT,
MLAGAN, PECAN, GERP_CONSERVATION_SCORES, etc.

GERP_CONSERVATION_SCORES are only supported when dumping in emf
format. The scores are dumped together with the orginal alignment.

=item B<[--set_of_species species1:species2:species3:...]>

The list of species used to get those alignments. The names should
correspond to the name of the core database in the
registry_configuration_file or any of its aliases

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

This script uses the Bio::AlignIO::xxx modules to format the output
except for the maf and emf formats because the Bio::AlignIO::maf module
does not support writting and there is no module for emf.

=item B<[--output_file filename]>

The name of the output file. By default the output is the
standard output

=item B<[--split_size split_size]>

Only available when dumping to a file. This will split the output
in several files. Each file will contain up to split-size alignments.

=item B<[--chunk_num chunk_num]>

Only available in conjunction with previous option. This option is
used to dump one of the files only (the first file is num. 1)

=back

=head1 EXAMPLES

=over

=item Dump all the human-mouse alignment on human chromosome X [1Mb-2Mb] in a multi fasta format:

perl DumpMultiAlign.pl --species "Homo sapiens" \
  --set_of_species "Homo sapiens:Mus musculus" \
  --alignment_type BLASTZ_NET --seq_region X \
  --seq_region_start 1000000 --seq_region_end 2000000 \
  --output_format fasta

=item Dump all the human-mouse alignment on human supercontigs in a clustalw format:

perl DumpMultiAlign.pl --species "Homo sapiens" \
  --set_of_species "Homo sapiens:Mus musculus" \
  --alignment_type BLASTZ_NET --coord_system supercontig \
  --output_format clustalw

=item Dump all the human-chicken alignment on human chromosome 1, returning soft-masked sequences:

perl DumpMultiAlign.pl --species "Homo sapiens" \
  --set_of_species "Homo sapiens:Mus musculus" \
  --alignment_type BLASTZ_NET --seq_region 1 --masked_seq 1

=item Dump all the 10 way multiple alignment on human chromosome Y in emf format:

perl DumpMultiAlign.pl --species "human" \
  --set_of_species "human:chimp:rhesus:mouse:rat:dog:cow:opossum:chicken:platypus" \
  --alignment_type PECAN --seq_region Y --masked_seq 1 \
  --output_format emf --output_file 10way_pecan_chrY.out

=item Same for chromosome 19 plus GERP conservation scores. Dump in chunks of 200 alignms:

perl DumpMultiAlign.pl --species "human" \
  --set_of_species "human:chimp:rhesus:mouse:rat:dog:cow:opossum:chicken:platypus" \
  --alignment_type GERP_CONSERVATION_SCORE --seq_region 19 --masked_seq 1 \
  --split_size 200 --output_format emf --output_file 10way_pecan_chr19.out

=item Same for chromosome 19 plus GERP conservation scores. Using chunks of 200 alignms, dump 2nd one:

perl DumpMultiAlign.pl --species "human" \
  --set_of_species "human:chimp:rhesus:mouse:rat:dog:cow:opossum:chicken:platypus" \
  --alignment_type GERP_CONSERVATION_SCORE --seq_region 19 --masked_seq 1 \
  --split_size 200 --output_format emf --output_file 10way_pecan_chr19.out \
  --chunk_num 2

=cut

my $usage = qq{
perl DumpMultiAlign.pl
  Getting help:
    [--help]

  General configuration:
    [--db mysql://user[:passwd]\@host[:port]]>
        The script will auto-configure the Registry using the
        databases in this MySQL instance. Default:
        mysql://anonymous\@ensembldb.ensembl.org

    [--reg_conf registry_configuration_file]
        the Bio::EnsEMBL::Registry configuration file. If none given,
        the one set in ENSEMBL_REGISTRY will be used if defined, if not
        ~/.ensembl_init will be used.
    [--dbname compara_db_name]
        the name of compara DB in the registry_configuration_file or any
        of its aliases. Uses "Multi" by default.

  For the query slice:
    [--species species]
        Query species. This can be used to define a query slice and dump
        alignments for this slice only
    [--seq_region region_name]
        Sequence region name of the query slice, i.e. the chromosome name
    [--seq_region_start start]
        Query slice start (default = 1)
    [--seq_region_end end]
        Query slice end (default = end)
    [--coord_system coordinates_name]
        This option allows to dump all the alignments on all the top-level
        sequence region of a given coordinate system. It can also be used
        in conjunction with the --seq_region option to specify the right
        coordinate system.
    [--skip_species species]
        Usefull for multiple alignments only. This will dump all the
        multiple alignments with no "species" part, i.e. you can get
        all the alignments with no mouse. This option overwrites the
        previous ones.

  For the alignments:
    [--alignment_type method_link_name]
        The type of alignment. This can be BLASTZ_NET, TRANSLATED_BLAT,
        MLAGAN, PECAN, GERP_CONSERVATION_SCORES, etc.
        NB: GERP_CONSERVATION_SCORES are only supported when dumping in emf
        format. The scores are dumped together with the orginal alignment.
    [--set_of_species species1:species2:species3:...]
        The list of species used to get those alignments. The names
        should correspond to the name of the core database in the
        registry_configuration_file or any of its aliases

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
        Only available when dumping to a file. This will split the output
        in several files. Each file will contain up to split-size alignments.
    [--chunk_num chunk_num]
        Only available in conjunction with previous option. This option is
        used to dump one of the files only (the first file is num. 1)

  SEE THE PERLDOC FOR MORE HELP!
};

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::SimpleAlign;
use Bio::AlignIO;
use Bio::LocatableSeq;
use Getopt::Long;
use Devel::Size qw (size total_size);

my $reg_conf;
my $db = 'mysql://anonymous@ensembldb.ensembl.org';
my $dbname = "Multi";
my $species;
my $skip_species;
my $coord_system;
my $seq_region;
my $seq_region_start;
my $seq_region_end;
my $alignment_type;
my $method_link_species_set_id;
my $set_of_species;
my $original_seq = undef;
my $masked_seq = 0;
my $output_file = undef;
my $output_format = "fasta";
my $split_size = 0;
my $chunk_num;
my $help;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "db=s" => \$db,
    "dbname=s" => \$dbname,
    "species=s" => \$species,
    "skip_species=s" => \$skip_species,
    "coord_system=s" => \$coord_system,
    "seq_region=s" => \$seq_region,
    "seq_region_start=i" => \$seq_region_start,
    "seq_region_end=i" => \$seq_region_end,
    "alignment_type=s" => \$alignment_type,
    "mlss_id|method_link_species_set_id=i" => \$method_link_species_set_id,
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
my $method_link_species_set;
if ($method_link_species_set_id) {
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
  throw("The database do not contain any alignments with a MLSS id = $method_link_species_set_id!")
      if (!$method_link_species_set);
} else {
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
          $alignment_type, $genome_dbs);
  throw("The database do not contain any $alignment_type data for $set_of_species!")
      if (!$method_link_species_set);
}

my $conservation_score_mlss;
if ($method_link_species_set->method_link_class eq "ConservationScore.conservation_score") {
  $conservation_score_mlss = $method_link_species_set;
  my $meta_container = Bio::EnsEMBL::Registry->get_adaptor(
    $dbname, 'compara', 'MetaContainer');
  my $mlss_id = $meta_container->list_value_by_key('gerp_'.$conservation_score_mlss->dbID)->[0];
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($mlss_id);
  throw("I cannot find the link from the conservation scores to the original alignments!")
      if (!$method_link_species_set);
}

print STDERR "Dumping ", $method_link_species_set->name, "\n";

# Fetching the query Slices:
my @query_slices;
if ($species and !$skip_species and ($coord_system or $seq_region)) {
  my $slice_adaptor;
  $slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'core', 'Slice');
  throw("Registry configuration file has no data for connecting to <$species>")
      if (!$slice_adaptor);
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
}

# Get the GenomicAlignBlockAdaptor:
my $genomic_align_block_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    $dbname, 'compara', 'GenomicAlignBlock');

my $genomic_align_tree_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    $dbname, 'compara', 'GenomicAlignTree');

my $release = Bio::EnsEMBL::Registry->get_adaptor(
    $dbname, 'compara', 'MetaContainer')->list_value_by_key("schema_version")->[0];
my $date = scalar(localtime());

my $use_several_files = 0;
if ($output_file and $split_size) {
  $use_several_files = 1;
}

my $slice_counter = 0;
my $start = 0;
my $num = 0;
if ($chunk_num and $split_size) {
  $num = $chunk_num - 1;
  $start = $split_size * $num;
}
if (!$use_several_files) {
  ## Open file now and create the header if needed
  if ($output_file) {
    open(STDOUT, ">$output_file") or die("Cannot open $output_file");
  }
  print_header($output_format, $method_link_species_set, $date, $release, 0);
}

## Get the full list of alignments with no $skip_species in $skip_species mode
my $skip_genomic_align_blocks = [];
if ($skip_species) {
  my $this_meta_container_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
      $skip_species, 'core', 'MetaContainer');
  throw("Registry configuration file has no data for connecting to <$skip_species>")
      if (!$this_meta_container_adaptor);
  $skip_species = $this_meta_container_adaptor->get_Species->binomial;

  $skip_genomic_align_blocks = $genomic_align_block_adaptor->
      fetch_all_by_MethodLinkSpeciesSet($method_link_species_set);
  for (my $i=0; $i<@$skip_genomic_align_blocks; $i++) {
    my $has_skip = 0;
    foreach my $this_genomic_align (@{$skip_genomic_align_blocks->[$i]->get_all_GenomicAligns()}) {
      if (($this_genomic_align->genome_db->name eq $skip_species) or
          ($this_genomic_align->genome_db->name eq "Ancestral sequences")) {
        $has_skip = 1;
        last;
      }
    }
    if ($has_skip) {
      my $this_genomic_align_block = splice(@$skip_genomic_align_blocks, $i, 1);
      $i--;
      $this_genomic_align_block = undef;
    }
  }
}

## MAIN DUMPING LOOP
do {
  my $genomic_align_blocks = [];
  if (!@query_slices) {
    ## We are fetching all the alignments
    if ($skip_species) {
      # skip_species mode: Use previoulsy obtained list of alignments
      $genomic_align_blocks = [splice(@$skip_genomic_align_blocks, $start, $split_size)];
      $start = 0;
    } else {
      # Get the alignments using the GABadaptor
      $genomic_align_blocks = $genomic_align_block_adaptor->
          fetch_all_by_MethodLinkSpeciesSet($method_link_species_set,
          $split_size, $start);
    }
  } else {
      while ((!$split_size or @$genomic_align_blocks < $split_size) and $slice_counter < @query_slices) {
        my $this_slice = $query_slices[$slice_counter];
        my $aln_left = 0;
        if ($split_size) {
          $aln_left = $split_size - @$genomic_align_blocks;
        }
        my $extra_genomic_align_blocks = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
            $method_link_species_set, $this_slice, $aln_left, $start);
        push(@$genomic_align_blocks, @$extra_genomic_align_blocks);
        if ($split_size and @$genomic_align_blocks >= $split_size) {
          $start += @$extra_genomic_align_blocks;
        } else {
          $slice_counter++;
          $start = 0;
        }
      }
  }

  if (@$genomic_align_blocks) {
    ## We've got something to dump
    if ($use_several_files) {
      ## In multi-files mode, need to open the new file and add the header if needed
      $num++;
      my $this_output_file = $output_file;
      if ($this_output_file =~ /\.[^\.]+$/) {
        $this_output_file =~ s/(\.[^\.]+)$/_$num$1/;
      } else {
        $this_output_file .= ".$num";
      }
      open(STDOUT, ">$this_output_file") or die("Cannot open $this_output_file");
      print_header($output_format, $method_link_species_set, $date, $release, $num);
    }

    ## Dump these alignments
    foreach my $this_genomic_align_block (@$genomic_align_blocks) {
      if ($method_link_species_set->method_link_class =~ /tree_alignment/) {
        $DB::single = 1;
        my $this_genomic_align_tree = $genomic_align_tree_adaptor->
            fetch_by_GenomicAlignBlock($this_genomic_align_block);
	if (!$this_genomic_align_tree) {
	  print STDERR "SKIP genomic_align_block ", $this_genomic_align_block->dbID, "\n";
	  next;
	}
        write_genomic_align_block($output_format, $this_genomic_align_tree);
        deep_clean($this_genomic_align_tree);
      } else {
        write_genomic_align_block($output_format, $this_genomic_align_block);
      }
      $this_genomic_align_block = undef;
    }

    ## chunk_num means that only this chunk has to be dumped:
    ## set the split_size to 0 in orer to exit the main loop
    if ($chunk_num) {
      $split_size = 0;
    }

  } else {
    ## No more genomic_align_blocks to dump: set split_size to 0 in orer to exit the main loop
    $split_size = 0;
  }
} while (($split_size and $slice_counter < @query_slices) or @$skip_genomic_align_blocks);

exit(0);


=head2 print_header

  Arg[1]     : string $output_format
  Arg[2]     : B::E::Compara::MethodLinkSpeciesSet $mlss
  Arg[3]     : [optional] string $date
  Arg[4]     : [optional] string $release_version
  Arg[5]     : [optional] int file_number
  Example    : print_header("emf", $mlss, 
  Description: 
  Returntype : 
  Exceptions : 

=cut

sub print_header {
  my ($output_format, $method_link_species_set, $date, $release, $num) = @_;

  if ($output_format eq "maf") {
    print "##maf version=1 program=", $method_link_species_set->method_link_type, "\n";
    print "#\n";
  } elsif ($output_format eq "emf") {
    print
      "##FORMAT (compara)\n",
      "##DATE $date\n",
      "##RELEASE ", $release, "\n",
      "# Alignments: ", $method_link_species_set->name, "\n";
    if ($skip_species) {
      print "# Region: ALL_ALIGNMENTS with no $skip_species regions\n";
    } elsif (!@query_slices) {
      print "# Region: ALL_ALIGNMENTS\n";
    } elsif ($coord_system and !$seq_region) {
      print "# Region: ALL ${coord_system}s\n";
    } else {
      my $slice = $query_slices[0];
      print "# Region: ",
          $slice->adaptor->db->get_MetaContainer->get_Species->binomial,
          " ", $slice->name, "\n";
    }
    print "# File $num\n" if ($num);
  }
}


=head2 write_genomic_align_block

  Arg[1]     : string $output_format (maf, emf or any BioPerl-supported format)
  Arg[2]     : B::E::Compara::GenomicAlignBlock $gab
  Example    : write_genomic_align_block("emf", $gab);
  Description: writes this $gab in the selected format to the
               standard output.
  Returntype : 
  Exceptions : 

=cut

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


=head2 print_my_emf

  Arg[1]     : B::E::Compara::GenomicAlignBlock $gab
  Example    : print_my_emf($gab);
  Description: writes this $gab in the EMF format to the
               standard output.
  Returntype : 
  Exceptions : 

=cut

sub print_my_emf {
  my ($genomic_align_block) = @_;
  return if (!$genomic_align_block);


# print STDERR "1. ", qx"ps v $$ | cut -c 1-80";
  print "\n";
  my $aligned_seqs;
  my $all_genomic_aligns;
  if (UNIVERSAL::isa($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
# $DB::single = 1;
    foreach my $this_genomic_align_tree (@{$genomic_align_block->get_all_sorted_genomic_align_nodes()}) {
      push(@{$all_genomic_aligns}, $this_genomic_align_tree->genomic_align_group);
    }
  } else {
    $all_genomic_aligns = $genomic_align_block->get_all_GenomicAligns()
  }
  my $reverse = 1 - $genomic_align_block->get_original_strand;
  foreach my $this_genomic_align (@{$all_genomic_aligns}) {
    my $species_name = $this_genomic_align->genome_db->name;
    $species_name =~ s/ /_/g;
    if (UNIVERSAL::isa($this_genomic_align, "Bio::EnsEMBL::Compara::GenomicAlignGroup") and
        @{$this_genomic_align->get_all_GenomicAligns} > 1) {
      my $length = 0;
      my @names;
      foreach my $this_sub_genomic_align (@{$this_genomic_align->get_all_GenomicAligns}) {
        push(@names, $this_sub_genomic_align->get_Slice->name);
        $length += $this_sub_genomic_align->dnafrag_end - $this_sub_genomic_align->dnafrag_start + 1;
      }
      print join(" ", "SEQ", $species_name, "Composite_".$this_genomic_align->dbID,
          1, $length, ($reverse?-1:1), "(chr_length=".$length.")"), "\n";
      print "### $species_name Composite_",$this_genomic_align->dbID, " is: ", join(" + ", @names), "\n";
    } else {
      print join(" ", "SEQ", $species_name, $this_genomic_align->dnafrag->name,
          $this_genomic_align->dnafrag_start, $this_genomic_align->dnafrag_end,
          $this_genomic_align->dnafrag_strand,
          "(chr_length=".$this_genomic_align->dnafrag->length.")"), "\n";
    }
    my $aligned_sequence;
    if (UNIVERSAL::isa($this_genomic_align, "Bio::EnsEMBL::Compara::GenomicAlignGroup")) {
      foreach my $this_sub_genomic_align (@{$this_genomic_align->get_all_GenomicAligns}) {
        if ($masked_seq == 1) {
          next if (!$this_sub_genomic_align->get_Slice);
          $this_sub_genomic_align->original_sequence($this_sub_genomic_align->get_Slice->get_repeatmasked_seq(undef,1)->seq);
        } elsif ($masked_seq == 2) {
          $this_sub_genomic_align->original_sequence($this_sub_genomic_align->get_Slice->get_repeatmasked_seq()->seq);
        }
      }
    } else {
      if ($masked_seq == 1) {
        next if (!$this_genomic_align->get_Slice);
        $this_genomic_align->original_sequence($this_genomic_align->get_Slice->get_repeatmasked_seq(undef,1)->seq);
      } elsif ($masked_seq == 2) {
        $this_genomic_align->original_sequence($this_genomic_align->get_Slice->get_repeatmasked_seq()->seq);
      }
    }
    if ($original_seq) {
      $aligned_sequence = $this_genomic_align->original_sequence;
    } else {
      $aligned_sequence = $this_genomic_align->aligned_sequence;
    }
    for (my $i = 0; $i<length($aligned_sequence); $i++) {
      $aligned_seqs->[$i] .= substr($aligned_sequence, $i, 1);
    }
    $aligned_sequence = undef;
  }
  if (UNIVERSAL::isa($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
    foreach my $this_genomic_align_tree (@{$genomic_align_block->get_all_sorted_genomic_align_nodes()}) {
      my $genomic_aligns = $this_genomic_align_tree->genomic_align_group->get_all_GenomicAligns();
      my $this_genomic_align = $genomic_aligns->[0];
      $this_genomic_align->dnafrag->genome_db->name =~ /(.)[^ ]+ (.{3})/;
      my $name = "${1}${2}_";
      if (@$genomic_aligns > 1) {
        $name .= "Composite_".$this_genomic_align_tree->genomic_align_group->dbID;
        my $length = 0;
        foreach my $this_genomic_align (@{$genomic_aligns}) {
          $length += $this_genomic_align->dnafrag_end - $this_genomic_align->dnafrag_start + 1;
        }
        $name .= "_1_${length}";
        if ($reverse) {
          $name .= "[-]";
        } else {
          $name .= "[+]";
        }
      } else {
        $this_genomic_align->dnafrag->genome_db->name =~ /(.)[^ ]+ (.{3})/;
        $name .= $this_genomic_align->dnafrag->name."_".
            $this_genomic_align->dnafrag_start."_".$this_genomic_align->dnafrag_end."[".
            (($this_genomic_align->dnafrag_strand eq "-1")?"-":"+")."]";
      }
      $this_genomic_align_tree->name($name);
    }
    print "TREE ", $genomic_align_block->newick_format, "\n";
  }
# # print STDERR "After tree:     ", total_size($genomic_align_block), "\n";
  if ($conservation_score_mlss) {
    print "SCORE ", $conservation_score_mlss->name, "\n";
    my $new_genomic_align_block = $genomic_align_block;
    if (UNIVERSAL::isa($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
      $new_genomic_align_block = $genomic_align_block->get_all_leaves->[0]->genomic_align_group->get_all_GenomicAligns->[0]->genomic_align_block;
      $new_genomic_align_block->reverse_complement if ($reverse);
    }
    my $conservation_scores = $new_genomic_align_block->adaptor->db->get_ConservationScoreAdaptor->
        fetch_all_by_GenomicAlignBlock($new_genomic_align_block, undef, undef, undef,
            $new_genomic_align_block->length, undef, 1);
    my $this_conservation_score = shift @$conservation_scores;
    for (my $i = 0; $i<@$aligned_seqs; $i++) {
      if ($this_conservation_score and $this_conservation_score->position == $i + 1) {
        $aligned_seqs->[$i] .= sprintf(" %.2f", $this_conservation_score->diff_score);
        $this_conservation_score = shift @$conservation_scores;
      } else {
        $aligned_seqs->[$i] .= " .";
      }
    }
    $new_genomic_align_block = undef;
  }

  print "DATA\n";
  print join("\n", @$aligned_seqs);
  print "\n//\n";
  $aligned_seqs = undef;
}


=head2 print_my_maf

  Arg[1]     : B::E::Compara::GenomicAlignBlock $gab
  Example    : print_my_maf($gab);
  Description: writes this $gab in the MAF format to the
               standard output.
  Returntype : 
  Exceptions : 

=cut

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

sub deep_clean {
  my ($genomic_align_tree) = @_;

  my $all_nodes = $genomic_align_tree->get_all_nodes;
  foreach my $this_genomic_align_node (@$all_nodes) {
    my $this_genomic_align_group = $this_genomic_align_node->genomic_align_group;
    foreach my $this_genomic_align (@{$this_genomic_align_group->get_all_GenomicAligns}) {
      foreach my $key (keys %$this_genomic_align) {
        if ($key eq "genomic_align_block") {
          foreach my $this_ga (@{$this_genomic_align->{$key}->get_all_GenomicAligns}) {
            $this_ga = undef;
          }
        }
        $this_genomic_align->{$key} = undef;
      }
      $this_genomic_align = undef;
    }
    $this_genomic_align_group = undef;
    $this_genomic_align_node = undef;
  }
}
