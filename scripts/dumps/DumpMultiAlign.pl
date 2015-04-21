#!/usr/bin/env perl -w
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


my $description = q{
###########################################################################
##
## PROGRAM DumpMultiAlign.pl
##
## AUTHORS
##    Abel Ureta-Vidal
##    Javier Herrero
##
## DESCRIPTION
##    This script dumps (pairwise or multiple) genomic alignments from
##    an EnsEMBL Compara Database.
##
###########################################################################

};

=head1 NAME

DumpMultiAlign.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 AUTHORS

 Abel Ureta-Vidal
 Javier Herrero

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

=item B<--seq_region_strand strand>

=back

=head2 SPECIFYING THE ALIGNMENT TYPE

=over

=item B<[--alignment_type method_link_name]>

The type of alignment. This can be BLASTZ_NET, TRANSLATED_BLAT,
MLAGAN, PECAN, GERP_CONSERVATION_SCORES, etc.

GERP_CONSERVATION_SCORES are only supported when dumping in emf
format. The scores are dumped together with the orginal alignment.

=item B<[--set_of_species species1:species2:species3:...]>

=item B<[--set_of_species species_set_name]>

The list of species used to get those alignments. The names
should correspond to the name of the core database in the
registry_configuration_file or any of its aliases. Alternatively,
you can use a pre-defined species_set_name like "mammals" or "primates".

=item B<[--restrict]>

Choose to restrict the alignments to the query slice. Off by default.

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
does not support writing and there is no module for emf.

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

=back

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
    [--seq_region_strand 1/-1]
        Query slice strand (default = 1)
    [--coord_system coordinates_name]
        This option allows to dump all the alignments on all the top-level
        sequence region of a given coordinate system. It can also be used
        in conjunction with the --seq_region option to specify the right
        coordinate system.
    [--skip_species species]
        Useful for multiple alignments only. This will dump all the
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
    [--set_of_species species_set_name]
        The list of species used to get those alignments. The names
        should correspond to the name of the core database in the
        registry_configuration_file or any of its aliases. Alternatively,
        you can use a pre-defined species_set_name like mammals or primates.
    [--restrict]
        Choose to restrict the alignments to the query slice. Off by default.
    [--file_of_genomic_align_block_ids filename]
        A file containing a list of the genomic_align_block_ids to dump. Note
        skip_species has no affect.

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
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;
use Devel::Size qw (size total_size);

my $reg = "Bio::EnsEMBL::Registry";
my $reg_conf;
my $dbs = ['mysql://anonymous@ensembldb.ensembl.org'];
my $dbname = "Multi";
my $compara_url;
my $species;
my $skip_species;
my $coord_system;
my $seq_region;
my $seq_region_start;
my $seq_region_end;
my $seq_region_strand = 1;
my $restrict = 0;
my $alignment_type;
my $method_link_species_set_id;
my $set_of_species;
my $original_seq = undef;
my $masked_seq = 0;
my $output_file = undef;
my $output_format = "fasta";
my $split_size = 0;
my $chunk_num;
my $file_of_genomic_align_block_ids;
my $help;
my $compara_dba;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "db=s@" => \$dbs,
    "dbname=s" => \$dbname,
    "compara_url=s" => \$compara_url,
    "species=s" => \$species,
    "skip_species=s" => \$skip_species,
    "coord_system=s" => \$coord_system,
    "seq_region=s" => \$seq_region,
    "seq_region_start=i" => \$seq_region_start,
    "seq_region_end=i" => \$seq_region_end,
    "seq_region_strand=i" => \$seq_region_strand,
    "restrict" => \$restrict,
    "alignment_type=s" => \$alignment_type,
    "mlss_id|method_link_species_set_id=i" => \$method_link_species_set_id,
    "set_of_species=s" => \$set_of_species,
    "original_seq" => \$original_seq,
    "masked_seq=i" => \$masked_seq,
    "output_format=s" => \$output_format,
    "output_file=s" => \$output_file,
    "split_size=s" => \$split_size,
    "chunk_num=s" => \$chunk_num,
    "file_of_genomic_align_block_ids=s" => \$file_of_genomic_align_block_ids,
  );

# Print Help and exit
if ($help) {
  print $description, $usage;
  exit(0);
}
# Configure the Bio::EnsEMBL::Registry
# Uses $reg_conf if supllied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses ~/.ensembl_init
# if all the previous fail.
$reg->no_version_check(1);
if ($reg_conf) {
  $reg->load_all($reg_conf);
} else {
    #Bio::EnsEMBL::Registry->load_registry_from_url($db);
    #Allow multiple dbs to be input 
    @$dbs = split(/,/, join(',', @$dbs));
    foreach my $db (@$dbs) {
	$reg->load_registry_from_url($db);
    }
}

#Set compara_dba
if ($compara_url) {
    $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$compara_url);
} else {
    $compara_dba = $reg->get_DBAdaptor($dbname, "compara");
}

#print "Connecting to compara_db " . $compara_dba->dbc->dbname . "\n";

# Getting Bio::EnsEMBL::Compara::MethodLinkSpeciesSet obejct
my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
throw("Unable to connect to compara adaptor")
    if (!$method_link_species_set_adaptor);

my $method_link_species_set;
if ($method_link_species_set_id) {
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($method_link_species_set_id);
  throw("The database do not contain any alignments with a MLSS id = $method_link_species_set_id!")
      if (!$method_link_species_set);
} elsif ($set_of_species =~ /\:/) {
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_registry_aliases(
          $alignment_type, [split(":", $set_of_species)]);
  throw("The database do not contain any $alignment_type data for $set_of_species!")
      if (!$method_link_species_set);
} elsif ($set_of_species) {
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_species_set_name(
          $alignment_type, $set_of_species);
  throw("The database do not contain any $alignment_type data for $set_of_species!")
      if (!$method_link_species_set);
}

my $conservation_score_mlss;
if ($method_link_species_set->method->class eq "ConservationScore.conservation_score") {
  $conservation_score_mlss = $method_link_species_set;
  my $mlss_id = $conservation_score_mlss->get_value_for_tag('msa_mlss_id');
  $method_link_species_set = $method_link_species_set_adaptor->fetch_by_dbID($mlss_id);
  throw("I cannot find the link from the conservation scores to the original alignments!")
      if (!$method_link_species_set);
}

print STDERR "Dumping ", $method_link_species_set->name, "\n";

# Fetching the query Slices:
my @query_slices;
if ($species and !$skip_species and ($coord_system or $seq_region)) {
  my $slice_adaptor;
  $slice_adaptor = $reg->get_adaptor($species, 'core', 'Slice');
  throw("Registry configuration file has no data for connecting to <$species>")
      if (!$slice_adaptor);
  if ($coord_system and !$seq_region) {
    @query_slices = grep {$_->coord_system_name eq $coord_system} @{$slice_adaptor->fetch_all('toplevel')};
    if (@query_slices == 0) {    
	print "No slices found with coord_system $coord_system\n";
	exit(0);
    } 
  } elsif ($coord_system) { # $seq_region is defined
    my $query_slice = $slice_adaptor->fetch_by_region(
        $coord_system, $seq_region, $seq_region_start, $seq_region_end, $seq_region_strand);
    throw("No Slice can be created with coordinates $seq_region:$seq_region_start-$seq_region_end:$seq_region_strand")
        if (!$query_slice);
    @query_slices = ($query_slice);
    if (@query_slices == 0) {    
	print "No slices found with coordinates $seq_region:$seq_region_start-$seq_region_end:$seq_region_strand\n";
	exit(0);
    } 
  } elsif ($seq_region) {
    my $query_slice = $slice_adaptor->fetch_by_region(
        'toplevel', $seq_region, $seq_region_start, $seq_region_end, $seq_region_strand);
    throw("No Slice can be created with coordinates $seq_region:$seq_region_start-$seq_region_end:$seq_region_strand")
        if (!$query_slice);
    @query_slices = ($query_slice);
    if (@query_slices == 0) {    
	print "No slices found with coordinates $seq_region:$seq_region_start-$seq_region_end:$seq_region_strand\n";
	exit(0);
    } 
  }
}

# Get the GenomicAlignBlockAdaptor or the GenomicAlignTreeAdaptor:
my $genomic_align_set_adaptor;
if ($method_link_species_set->method->class =~ /GenomicAlignTree/) {
  $genomic_align_set_adaptor = $compara_dba->get_GenomicAlignTreeAdaptor;
} else {
  $genomic_align_set_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor;
}

#Need if get genomic_align_blocks from file_of_genomic_align_block_ids
my  $genomic_align_block_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor;

my $release = $compara_dba->get_MetaContainer()->get_schema_version();
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
## Do not do this if have defined a $file_of_genomic_align_block_ids
my $skip_genomic_align_blocks = [];
if ($skip_species && !$file_of_genomic_align_block_ids) {
  my $this_meta_container_adaptor = $reg->get_adaptor(
      $skip_species, 'core', 'MetaContainer');
  throw("Registry configuration file has no data for connecting to <$skip_species>")
      if (!$this_meta_container_adaptor);
  $skip_species = $this_meta_container_adaptor->get_scientific_name;

  $skip_genomic_align_blocks = $genomic_align_set_adaptor->
      fetch_all_by_MethodLinkSpeciesSet($method_link_species_set);
  for (my $i=0; $i<@$skip_genomic_align_blocks; $i++) {
    my $has_skip = 0;
    foreach my $this_genomic_align (@{$skip_genomic_align_blocks->[$i]->get_all_GenomicAligns()}) {
      if (($this_genomic_align->genome_db->name eq $skip_species) or
          ($this_genomic_align->genome_db->name eq "ancestral_sequences")) {
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
  if ($file_of_genomic_align_block_ids) {
    open(FILE, $file_of_genomic_align_block_ids) or die ("Cannot open $file_of_genomic_align_block_ids");
    while (<FILE>) {
	chomp;
	my $gab;
	if ($method_link_species_set->method->class =~ /GenomicAlignTree/) {
	    $gab = $genomic_align_set_adaptor->fetch_by_genomic_align_block_id($_);
	} else {
	    $gab = $genomic_align_set_adaptor->fetch_by_dbID($_);
	}
	push @$genomic_align_blocks, $gab;
    }
    close(FILE);
  } elsif (!@query_slices) {
    ## We are fetching all the alignments
    if ($skip_species) {
      # skip_species mode: Use previoulsy obtained list of alignments
      $genomic_align_blocks = [splice(@$skip_genomic_align_blocks, $start, $split_size)];
      $start = 0;
    } else {
      # Get the alignments using the GABadaptor
      $genomic_align_blocks = $genomic_align_set_adaptor->
          fetch_all_by_MethodLinkSpeciesSet($method_link_species_set,
          $split_size, $start);
    }
  } else {
      while ((!$split_size or @$genomic_align_blocks < $split_size) and $slice_counter < @query_slices) {
        my $this_slice = $query_slices[$slice_counter];
        my $dnafrag_adaptor = $compara_dba->get_DnaFragAdaptor();
        my $this_dnafrag = $dnafrag_adaptor->fetch_by_Slice($this_slice);
        my $aln_left = 0;
        if ($split_size) {
          $aln_left = $split_size - @$genomic_align_blocks;
        }
        #Call fetch_all_by_MethodLinkSpeciesSet_DnaFrag rather than fetch_all_by_MethodLinkSpeciesSet_Slice because of
        #issues with the PAR regions. The _Slice method will dumps alignments on the PAR whereas _DnaFrag will not.
        my $extra_genomic_align_blocks = $genomic_align_set_adaptor->fetch_all_by_MethodLinkSpeciesSet_DnaFrag(
            $method_link_species_set, $this_dnafrag, $this_slice->start, $this_slice->end, $aln_left, $start, $restrict);

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
      if ($this_genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignTree")) {
        write_genomic_align_block($output_format, $this_genomic_align_block);
        deep_clean($this_genomic_align_block);
        $this_genomic_align_block->release_tree();
      } else {
        write_genomic_align_block($output_format, $this_genomic_align_block);
        $this_genomic_align_block = undef;
      }
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
#} while ($split_size or $slice_counter < @query_slices);
#} while ($split_size && $slice_counter < @query_slices);
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

  if ($output_format =~ /^maf$/i) {
    print "##maf version=1 program=", $method_link_species_set->method->type, "\n";
    print "#\n";
  } elsif ($output_format =~ /^emf$/i) {
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
        $slice->adaptor->db->get_MetaContainer->get_scientific_name, 
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

  if ($output_format =~ /^maf$/i) {
    return print_my_maf($this_genomic_align_block);
  } elsif ($output_format =~ /^emf$/i) {
    return print_my_emf($this_genomic_align_block);
  }
  my $alignIO = Bio::AlignIO->newFh(
          -interleaved => 0,
          -fh => \*STDOUT,
          -format => $output_format,
          -idlength => 10
      );
  my $simple_align = Bio::SimpleAlign->new();


  #only valid for a GenomicAlignBlock not a GenomicAlignTree
  if (!UNIVERSAL::isa($this_genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
      $simple_align->id("GAB#".$this_genomic_align_block->dbID);
      $simple_align->score($this_genomic_align_block->score);
  }

  my $genomic_aligns;

  if (UNIVERSAL::isa($this_genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
      $genomic_aligns = $this_genomic_align_block->get_all_leaves;
  } else {
      $genomic_aligns = $this_genomic_align_block->get_all_GenomicAligns;
  }

  foreach my $this_genomic_align (@$genomic_aligns) {
    my $seq_name;
      if (UNIVERSAL::isa($this_genomic_align, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
      $seq_name = $this_genomic_align->genomic_align_group->genome_db->name;
      $seq_name =~ s/(.)\w* (...)\w*/$1$2/;
      $seq_name .= ".".$this_genomic_align->genomic_align_group->dnafrag->name;
      } else {
      $seq_name = $this_genomic_align->dnafrag->genome_db->name;
      $seq_name =~ s/(.)\w* (...)\w*/$1$2/;
      $seq_name .= ".".$this_genomic_align->dnafrag->name;
      $seq_name = $simple_align->id().":".$seq_name if ($output_format eq "fasta");
      } 
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
    my ($dnafrag_start, $dnafrag_end, $dnafrag_strand);
    if (UNIVERSAL::isa($this_genomic_align, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {  
    $dnafrag_start = $this_genomic_align->genomic_align_group->dnafrag_start;
    $dnafrag_end = $this_genomic_align->genomic_align_group->dnafrag_end;
    $dnafrag_strand = $this_genomic_align->genomic_align_group->dnafrag_strand;
    } else {
    $dnafrag_start = $this_genomic_align->dnafrag_start;
    $dnafrag_end = $this_genomic_align->dnafrag_end;
    $dnafrag_strand = $this_genomic_align->dnafrag_strand;
    }


    my $seq;
    $seq = Bio::LocatableSeq->new(
            -SEQ    => $aligned_sequence,
            -START  => $dnafrag_start,
            -END    => $dnafrag_end,
            -ID     => $seq_name,
            -STRAND => $dnafrag_strand
        );
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
  my $is_a_genomic_align_tree;
  if (UNIVERSAL::isa($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
    $is_a_genomic_align_tree = 1;
    foreach my $this_genomic_align_tree (@{$genomic_align_block->get_all_sorted_genomic_align_nodes()}) {
      next if (!$this_genomic_align_tree->genomic_align_group);
      push(@{$all_genomic_aligns}, $this_genomic_align_tree->genomic_align_group);
    }
  } else {
    $all_genomic_aligns = $genomic_align_block->get_all_GenomicAligns()
  }
  my $reverse = 1 - $genomic_align_block->original_strand;
  foreach my $this_genomic_align (@{$all_genomic_aligns}) {
    next if (!defined($this_genomic_align));

    #find species_name
    my $species_name;
    $species_name = $this_genomic_align->genome_db->name;
    $species_name =~ s/ /_/g;
    my $seq_name = $this_genomic_align->dnafrag->name;

    my ($dnafrag_name, $dnafrag_start, $dnafrag_end, $dnafrag_length, $dnafrag_strand) =
        get_coordinates($this_genomic_align, $reverse);
    print join(" ", "SEQ", $species_name, $dnafrag_name,
        $dnafrag_start, $dnafrag_end, $dnafrag_strand,
        "(chr_length=".$dnafrag_length.")"), "\n";

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
      #Fixed memory problem. Don't need these anymore
      if (UNIVERSAL::isa($this_genomic_align, "Bio::EnsEMBL::Compara::GenomicAlignGroup")) {
	  my $gas = $this_genomic_align->get_all_GenomicAligns; 
	  foreach my $ga (@$gas) {
	      undef($ga->{original_sequence});
	      undef($ga->{aligned_sequence});
	  }
      } else {
	  undef($this_genomic_align->{original_sequence});
	  undef($this_genomic_align->{aligned_sequence});
      }
    for (my $i = 0; $i<length($aligned_sequence); $i++) {
      $aligned_seqs->[$i] .= substr($aligned_sequence, $i, 1);
    }
    $aligned_sequence = undef;
  }
  if (UNIVERSAL::isa($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
    foreach my $this_genomic_align_tree (@{$genomic_align_block->get_all_sorted_genomic_align_nodes()}) {
      my $genomic_align_group = $this_genomic_align_tree->genomic_align_group;
      next if (!defined $genomic_align_group);

      my $genomic_aligns = $genomic_align_group->get_all_GenomicAligns();
      my $this_genomic_align = $genomic_aligns->[0];
      $this_genomic_align->dnafrag->genome_db->name =~ /(.)[^ ]+_(.{3})/;
      my $name = "${1}${2}_";
      $name = ucfirst($name);
      if (@$genomic_aligns > 1) {
        my $dbID;
        if ($this_genomic_align_tree->genomic_align_group->dbID) {
            $dbID = $this_genomic_align_tree->genomic_align_group->dbID;
        } else {
            $dbID = $this_genomic_align_tree->genomic_align_group->{original_dbID};
        }
        #$name .= "Composite_".$this_genomic_align_tree->genomic_align_group->dbID;
        $name .= "Composite_".$dbID;
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
        $this_genomic_align->dnafrag->genome_db->name =~ /(.)[^ ]+_(.{3})/;
        $name .= $this_genomic_align->dnafrag->name."_".
            $this_genomic_align->dnafrag_start."_".$this_genomic_align->dnafrag_end."[".
            (($this_genomic_align->dnafrag_strand eq "-1")?"-":"+")."]";
      }
      $this_genomic_align_tree->name($name);
    }
    print "TREE ", $genomic_align_block->newick_format, "\n";
  }

  if ($conservation_score_mlss) {
    print "SCORE ", $conservation_score_mlss->name, "\n";

    my $start = 1;
    my $end = $genomic_align_block->length;
    my $length = $end-$start+1;

    my $conservation_scores = $genomic_align_block->adaptor->db->get_ConservationScoreAdaptor->
        fetch_all_by_GenomicAlignBlock($genomic_align_block, $start, $end, $length, $length, undef, 1);

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
  #$aligned_seqs = undef;
  undef($aligned_seqs);
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
  if (UNIVERSAL::isa($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignBlock") && defined $genomic_align_block->score) {
    print " score=", $genomic_align_block->score;
  }
  print "\n";
  my $all_genomic_aligns = [];
  my $is_a_genomic_align_tree;
  if (UNIVERSAL::isa($genomic_align_block, "Bio::EnsEMBL::Compara::GenomicAlignTree")) {
    $is_a_genomic_align_tree = 1;
    foreach my $this_genomic_align_tree (@{$genomic_align_block->get_all_sorted_genomic_align_nodes()}) {
      next if (!$this_genomic_align_tree->genomic_align_group);
      push(@{$all_genomic_aligns}, $this_genomic_align_tree->genomic_align_group);
    }
  } else {
    $all_genomic_aligns = $genomic_align_block->get_all_GenomicAligns()
  }
  my $reverse = 1 - $genomic_align_block->original_strand;
  foreach my $this_genomic_align (@$all_genomic_aligns) {
    my $seq_name = $this_genomic_align->genome_db->name;
    $seq_name =~ s/(.)\w* (...)\w*/$1$2/;
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
    my ($dnafrag_name, $dnafrag_start, $dnafrag_end, $dnafrag_length, $dnafrag_strand) =
        get_coordinates($this_genomic_align, $reverse);
    if ($dnafrag_strand == 1) {
      printf("s %-20s %10d %10d + %10d %s\n",
          "$seq_name.$dnafrag_name",
          $dnafrag_start-1,
          ($dnafrag_end - $dnafrag_start + 1),
          $dnafrag_length,
          $aligned_sequence);
    } else {
      printf("s %-20s %10d %10d - %10d %s\n",
          "$seq_name.$dnafrag_name",
          ($dnafrag_length - $dnafrag_end),
          ($dnafrag_end - $dnafrag_start + 1),
          $dnafrag_length,
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
    next if (!$this_genomic_align_group);
    foreach my $this_genomic_align (@{$this_genomic_align_group->get_all_GenomicAligns}) {
      foreach my $key (keys %$this_genomic_align) {
        if ($key eq "genomic_align_block") {
          foreach my $this_ga (@{$this_genomic_align->{$key}->get_all_GenomicAligns}) {
            my $gab = $this_ga->{genomic_align_block};
            my $gas = $gab->{genomic_align_array};
            if ($gas) {
              for (my $i = 0; $i < @$gas; $i++) {
                delete($gas->[$i]);
              }
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

sub get_coordinates {
  my ($this_genomic_align, $reverse) = @_;
  my ($dnafrag_name, $dnafrag_start, $dnafrag_end, $dnafrag_length, $dnafrag_strand);

  my $species_name = $this_genomic_align->genome_db->name;
  if ($this_genomic_align->can("get_all_GenomicAligns") and @{$this_genomic_align->get_all_GenomicAligns} > 1) {
    ## This is a composite segment.
    my @names;
    $dnafrag_length = 0;
    foreach my $this_composite_genomic_align (@{$this_genomic_align->get_all_GenomicAligns}) {
      push(@names, $this_composite_genomic_align->get_Slice->name);
      my $aligned_seq = $this_composite_genomic_align->aligned_sequence;
      $aligned_seq=~s/[-\.]//g; #remove the gaps and padding
      $dnafrag_length += length($aligned_seq);
    }
    my $dbID;
    if ($this_genomic_align->dbID) {
        $dbID = $this_genomic_align->dbID;
    } else {
        $dbID = $this_genomic_align->{original_dbID};
    }

    #$dnafrag_name = $this_genomic_align->dnafrag->name."_".$this_genomic_align->dbID;
    $dnafrag_name = $this_genomic_align->dnafrag->name."_".$dbID;
    print "### $species_name $dnafrag_name is: ", join(" + ", @names), "\n";
    $dnafrag_start = 1;
    $dnafrag_end = $dnafrag_length;
    $dnafrag_strand = ($reverse?-1:1);
  } else {
    $dnafrag_name = $this_genomic_align->dnafrag->name;
    $dnafrag_start = $this_genomic_align->dnafrag_start;
    $dnafrag_end = $this_genomic_align->dnafrag_end;
    $dnafrag_length = $this_genomic_align->dnafrag->length;
    $dnafrag_strand = $this_genomic_align->dnafrag_strand;
  }

  return ($dnafrag_name, $dnafrag_start, $dnafrag_end, $dnafrag_length, $dnafrag_strand);
}
