#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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


=head1 NAME

store_multiz_alignment.pl

=head1 AUTHOR

Javier Herrero

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

This software is part of the EnsEMBL project.

=head1 DESCRIPTION

This program reads a multiz file and stores all the alignments into the
selected database.

=head1 USAGE

store_multiz_alignment.pl [-help]
  --host mysql_host_server (for ensembl_compara DB)
  --dbuser db_username (default = 'ensro')
  --dbname ensembl_compara_database
  --port mysql_host_port (default = 3352)
  --reg_conf registry_conf_file
  --multiz_file file_containing_multiz_alignemnts
  --skip (ignores unknown genome assemblies and skips the whole alignment)
  --force (ignores unknown genome assemblies but stores the remaining sequences of the aligment)
  --score minimum_score_threhold (default No minimum)
  --min_seq minimum_number_of_sequences_in_the_multiple_alignment (default No minimum)
  --species string describing all the species used for this alignments. Use the UCSC species
      names concatenated with underscores '_', like hg18_panTro1_rheMac2_mm8_rn4_oryCun1_canFam2
  --load_dnafrags (loads all the toplevel seq_regions from the core db as dnafrags in the
      compara one)

=head1 BEFORE RUNNING THE SCRIPT

=head2 Download multiz files

All the files should be in the same directory. They are expected to have the extension <.maf>.
Gzipped and bzip2'ed files are allowed.

=head2 Download the goldenpath files from UCSC

There might some subtle differences between the ensembl and the ucsc assemblies in chromosomes Un,
genescaffold and so on. They are not mandatory, but these files will allow this script to map most
of the regions onto ensembl toplevel coordinates.

You can have one single file per species. If UCSC provides this information in several files,
you will have to concatenate them. The filename must be the UcscSpeciesName_gold.txt like
danRer3_gold.txt or panTro1_gold.txt


=head1 KNOWN BUGS

(*) DnaFrag entries must exist in the database. Fake DnaFrag used as a consensus
DnaFrag for multiple alignments must exist as well.

(*) Information needed to map UCSC species names into EnsEMBL naming system is
hard-coded and thus will get out-to-date at some stage.

(*) This program does not check for duplicates.

(*) With -skip option on, this program simply ignores the whole alignment when if finds an entries corresponding to unknown genome assemblies.

(*) With -force option on, this program simply ignores entries corresponding to unknown genome assemblies.

(*) This script has not been fully tested yet...

=head1 INTERNAL FUNCTIONS

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw( throw warning info );
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Mapper;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;

verbose("OFF");

###############################################################################
##  CONFIGURATION VARIABLES:
##   (*) $ucsc_2_ensembl:  maps the UCSC species names into the EnseEMBL
##           species naming system.
###############################################################################
my $ucsc_2_ensembl = {
      "hg18"    => {'name' => "Homo sapiens", 'assembly' => "NCBI36"},
      "panTro1" => {'name' => "Pan troglodytes", 'assembly' => "CHIMP1A"},
      "rheMac2" => {'name' => "Macaca mulatta", 'assembly' => "MMUL_1"},
      "mm8"     => {'name' => "Mus musculus", 'assembly' => "NCBIM36"},
      "rn4"     => {'name' => "Rattus norvegicus", 'assembly' => "RGSC3.4"},
      "oryCun1" => {'name' => "Oryctolagus cuniculus", 'assembly' => "RABBIT"},
      "canFam2" => {'name' => "Canis familiaris", 'assembly' => "BROADD2"},
      "bosTau2" => {'name' => "Bos taurus", 'assembly' => "Btau_2.0"},
      "dasNov1" => {'name' => "Dasypus novemcinctus", 'assembly' => "ARMA"},
      "loxAfr1" => {'name' => "Loxodonta africana", 'assembly' => "BROADE1"},
      "echTel1" => {'name' => "Echinops telfairi", 'assembly' => "TENREC"},
      "monDom4" => {'name' => "Monodelphis domestica", 'assembly' => "BROADO3"},
      "galGal2" => {'name' => "Gallus gallus", 'assembly' => "WASHUC1"},
      "xenTro1" => {'name' => "Xenopus tropicalis", 'assembly' => "JGI4.1"},
      "danRer3" => {'name' => "Danio rerio", 'assembly' => "ZFISH5"},
      "tetNig1" => {'name' => "Tetraodon nigroviridis", 'assembly' => "TETRAODON7"},
      "fr1"     => {'name' => "Takifugu rubripes", 'assembly' => "FUGU3"},
# 
#       "hg16" => {'name' => "Homo sapiens", 'assembly' => "NCBI34"},
#       "hg17" => {'name' => "Homo sapiens", 'assembly' => "NCBI35"},
#       "Mm3"  => {'name' => "Mus musculus", 'assembly' => "NCBIM32"},
#       "Mm5"  => {'name' => "Mus musculus", 'assembly' => "NCBIM33"},
#       "Rn3"  => {'name' => "Rattus norvegicus", 'assembly' => "RGSC3.1"},
#       "Gg2" => {'name' => "Gallus gallus", 'assembly' => "WASHUC1"},
#       "Pt1" => {'name' => "Pan troglodytes", 'assembly' => "CHIMP1"},
    };

###############################################################################

my $usage = qq{USAGE:
$0 [-help]
  -host mysql_host_server (for ensembl_compara DB)
  -dbuser db_username (default = 'ensro')
  -dbname ensembl_compara_database
  -port mysql_host_port (default = 3352)
  -reg_conf registry_conf_file
  -multiz directory_containing_multiz_alignemnts
  -skip (ignores unknown genome assemblies and skips the whole alignment)
  -force (ignores unknown genome assemblies but stores the remaining sequences
      of the aligment)
  -score minimum_score_threhold (default No minimum)
  -min_seq minimum_number_of_sequences_in_the_multiple_alignment (default No minimum)
};

my $help = 0;
my $dbname = "compara";
my $reg_conf;
my $multiz_dir;
my $species_string;
my $skip = 0;
my $force = 0;
my $score_threshold;
my $sequences_threshold;
my $check_sequences = 1;
my $load_dnafrags = 0;


GetOptions(
    'help' => \$help,
    'dbname=s' => \$dbname,
    'reg_conf=s' => \$reg_conf,
    'skip' => \$skip,
    'force' => \$force,
    'multiz=s' => \$multiz_dir,
    'species=s' => \$species_string,
    'score=i' => \$score_threshold,
    'min_seq=i' => \$sequences_threshold,
    'check_sequences!' => \$check_sequences,
    'load_dnafrags!' => \$load_dnafrags,
  );

if ($help) {
  pod2usage({-exitvalue => 0, -verbose => 2});
}

Bio::EnsEMBL::Registry->load_all($reg_conf);


## Read directory and get the list of multiz files
if (!$multiz_dir or !opendir(MULTIZ_DIR, $multiz_dir)) {
  print "ERROR: Cannot open <$multiz_dir> directory!\n", $usage;
  exit(1);
}
my @multiz_files = grep { /\.maf/ } readdir(MULTIZ_DIR);
closedir(MULTIZ_DIR);


## Get Compara adaptors
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomeDB');
die "Cannot get adaptor for '$dbname', 'compara', 'GenomeDB'" if (!$genome_db_adaptor);
my $dnafrag_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'DnaFrag');
my $genomic_align_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomicAlign');
my $genomic_align_block_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomicAlignBlock');
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'MethodLinkSpeciesSet');

my $print_multiple_alignment = ""; # used for warnings
my $score = 0;
my $malign_warning = "";
my %all_warnings;

my $all_alignments_counter = 0;
my $stored_alignments_counter = 0;

## Parse directory name in order to get species
if (!$species_string and $multiz_dir =~ /mz((\w\w[\d]+)+)/) {
  $species_string = $1;
  $species_string =~ s/(\d)(\w)/$1_$2/g;
}

## Store (or get) the MethodLinkSpeciesSet object
if (!$species_string) {
  print "ERROR: Species not defined and cannot be guessed from mavid directory name!\n", $usage;
  exit(1);
}
my @species  = split("_", $species_string);
my $species_set;
my $genome_db;
foreach my $this_species (@species) {
  if (!$ucsc_2_ensembl->{$this_species}) {
    warning("Species [$this_species] has not been configured!");
    print "Do you want to continue with the remaining speceis? ";
    my $resp = <STDIN>;
    next if ($resp =~ /^y/i);
    exit(1);
  }
#   print STDERR "get $this_species name " . $ucsc_2_ensembl->{$this_species}->{'name'} . " assem " . $ucsc_2_ensembl->{$this_species}->{'assembly'} . "\n";										

  $genome_db->{$this_species} = $genome_db_adaptor->fetch_by_name_assembly(
      $ucsc_2_ensembl->{$this_species}->{'name'},
      $ucsc_2_ensembl->{$this_species}->{'assembly'}
  );
  if (!$genome_db->{$this_species}) {
    warning("Assembly ".$ucsc_2_ensembl->{$this_species}->{'assembly'}." of species [$this_species] is not loaded!");
    print "Do you want to continue with the remaining species? ";
    my $resp = <STDIN>;
    next if ($resp =~ /^y/i);
    exit(1);
  }
  if ($load_dnafrags) {
    Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_dnafrags($dnafrag_adaptor->db, $genome_db->{$this_species});
  }
  push (@$species_set, $genome_db->{$this_species});
}

# print STDERR "check_sequences $check_sequences skip $skip\n";

my $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -adaptor => $method_link_species_set_adaptor,
        -method => new Bio::EnsEMBL::Compara::Method( -type => 'MULTIZ' ),
        -species_set => new Bio::EnsEMBL::Compara::SpeciesSet( -genome_dbs => $species_set ),
    );

# This method stores the new method_link_species_set and return the object with a new dbID. IF
# the object already exists on the DB, it returns the object with the existing dbID
$method_link_species_set = $method_link_species_set_adaptor->store($method_link_species_set);

foreach my $multiz_file (@multiz_files) {
#     print "file $multiz_file\n";

  ## Open file, decompressing it on the fly if needed
  if ($multiz_file =~ /\.gz$/) {
    open(MULTIZ, "gunzip -c $multiz_dir/$multiz_file |") || die;
  } elsif ($multiz_file =~ /\.bz2$/) {
    open(MULTIZ, "bzcat $multiz_dir/$multiz_file |");
  } else {
    open(MULTIZ, "$multiz_dir/$multiz_file");
  }

  my @all_these_genomic_aligns; # array of Bio::EnsEMBL::Compara::GenomicAlign objects to store as a single multiple alignment
  while (<MULTIZ>) {
    next if ($_ =~ /^$/ or $_ =~ /^#/);
    ## For all lines that are not "s" lines (parts of the multiple alignment)
    if (!/^s\s+([^\.]+)\.(\S+)\s+(\d+)\s+(\d+)\s+([\+\-])\s+(\d+)\s+(.+)$/) {

      ## Stores multiple alignment
      if (@all_these_genomic_aligns) {
        # -force option can produce alignments with one sequence only!!
        if (defined($sequences_threshold) && (@all_these_genomic_aligns < $sequences_threshold)) {
          $malign_warning .= "- Not Enough Sequences -";
        }
        if (!$malign_warning) {
          my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                  -adaptor => $genomic_align_block_adaptor,
                  -genomic_align_array => \@all_these_genomic_aligns,
                  -method_link_species_set => $method_link_species_set,
                  -score => $score
              );
          info("storing:\n$print_multiple_alignment\n");
          $genomic_align_block_adaptor->store($this_genomic_align_block);
          $stored_alignments_counter++;
        } else {
          print STDERR "SKIPPING: $malign_warning\n";
        }
        $malign_warning = "";
        undef(@all_these_genomic_aligns);
        $print_multiple_alignment = "";
        $score = undef;
      }

      ## Retrieves score of the multiple alignment
      if (/^a/ && /score=(\-?\d+(\.\d+)?)/) {
        $score = $1;
        if (defined($score_threshold) && ($score < $score_threshold)) {
          $malign_warning .= "- score=$score -";
        }
        $all_alignments_counter++;
      } else {
        throw("Error while parsing line $_");
      }

      next;
    }

    ## Next is for "s" lines only  
    $print_multiple_alignment .= "  $1.chr$2 $3 (l=$4) ($5) $6\n";

    my $species = $1;
    my $chromosome = $2;
    my $start_pos = $3;
    my $length = $4;
    my $strand = ($5 eq '+')?1:-1;
    my $chr_length = $6;
    my $aligned_sequence = $7;
    
    $chromosome =~ s/^chr//;
# 	     print STDERR "species=$species chr=$chromosome start=$start_pos len=$length strand=$strand \n";

    ## Deal with unknown assemblies
    if (!defined($ucsc_2_ensembl->{$species})) {
      $print_multiple_alignment =~ s/\n$/  **NOT AVAILABLE**\n/;;
      if ($force) {
        print "IGNORING: Species $species\n  $species.chr$chromosome $start_pos (l=$length) (", (($strand==1)?"+":"-"), ")\n";
        $all_warnings{"Species $species"}++;
        next;
      } elsif ($skip) {
        $all_warnings{"Species $species"}++;
        $malign_warning .= "- $species (".$all_warnings{"Species $species"}.") -";
        next;
      } else {
        print "$print_multiple_alignment\n";
        die "Cannot map UCSC species name: $species\n";
      }
    }

    my $genomic_align = get_this_genomic_align($species, $chromosome, $chr_length, $start_pos, $length, $strand,
          $aligned_sequence);
    next if (!$genomic_align);

    if ($check_sequences) {
      my $db_sequence = uc($genomic_align->dnafrag->slice->subseq(
              $genomic_align->dnafrag_start,
              $genomic_align->dnafrag_end,
              $genomic_align->dnafrag_strand
          ));
      my $multiz_sequence = uc($genomic_align->original_sequence);
      my $err_str = 
          "Error while retrieving sequence ".
          $ucsc_2_ensembl->{$species}->{'name'}.
          ", chromosome $chromosome [". $genomic_align->dnafrag->name.":".
          $genomic_align->dnafrag_start. "-". $genomic_align->dnafrag_end. "] ".
          (($strand == 1)?"(+)":"(-)")." -- (MULTIZ start:$start_pos length:$length\n".
          " DATABS: ". substr($db_sequence, 0, 10). "..".
          substr($db_sequence, -11). "\n".
          " MULTIZ: ". substr($multiz_sequence, 0, 10). "..".
          substr($multiz_sequence, -11);
      if ($db_sequence ne $multiz_sequence) {
        my $ga_start = $genomic_align->dnafrag_start;
        my $ga_end = $genomic_align->dnafrag_end;
        $genomic_align->dnafrag_strand($genomic_align->dnafrag_strand);
        $genomic_align->dnafrag_start($genomic_align->dnafrag->slice->end - $ga_end + 1);
        $genomic_align->dnafrag_end($genomic_align->dnafrag->slice->end - $ga_start + 1);
        $db_sequence = uc($genomic_align->dnafrag->slice->subseq(
                $genomic_align->dnafrag_start,
                $genomic_align->dnafrag_end,
                $genomic_align->dnafrag_strand
            ));
        if ($db_sequence eq $multiz_sequence) {
          warning("Reversing ".$genomic_align->dnafrag->slice->name);
        }
      }
      if ($db_sequence ne $multiz_sequence) {
        warning($err_str);
        <STDIN>;
        next;
      }
    }
    push(@all_these_genomic_aligns, $genomic_align);
  }
 
  ## Stores multiple alignment
  if (@all_these_genomic_aligns) {
    # -force option can produce alignments with one sequence only!!
    if (defined($sequences_threshold) && (@all_these_genomic_aligns < $sequences_threshold)) {
      $malign_warning .= "- Not Enough Sequences -";
    }
    if (!$malign_warning) {
      my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
              -adaptor => $genomic_align_block_adaptor,
              -genomic_align_array => \@all_these_genomic_aligns,
              -method_link_species_set => $method_link_species_set,
              -score => $score
          );
      info("storing:\n$print_multiple_alignment\n");
      $genomic_align_block_adaptor->store($this_genomic_align_block);
      $stored_alignments_counter++;
    } else {
      print STDERR "SKIPPING: $malign_warning\n";
    }
    $malign_warning = "";
    undef(@all_these_genomic_aligns);
    $print_multiple_alignment = "";
    $score = undef;
  }
  close(MULTIZ);
}

if (%all_warnings) {
  print "LIST OF UNKNOWN OBJECTS:\n";
  while (my($warning, $count) = each %all_warnings) {
    print " - $warning ($count)\n";
  }
  print "\n";
}

print "End. $stored_alignments_counter multiple alignments out of $all_alignments_counter have been stored.\n";
 
exit(0);


=head2 get_this_dnafrag

  Arg [1]    : string $species
  Arg[2]     : string $fragment_name
  Example    : get_this_danfrag($human_db, 'chromosome', '17');
  Description: Returns the corresponding DnaFrag object.
  Returntype : Bio::EnsEMBL::Compara::DnaFrag
  Exceptions : returns undef when the DnaFrag does not exist in the database.

=cut

my $dnafrag_mapper;
sub get_this_genomic_align {
  my ($species, $name, $seq_region_length, $start_pos, $length, $strand, $aligned_sequence) = @_;

  my ($dnafrag_start, $dnafrag_end, $dnafrag_strand);

  if ($genome_db->{$species}->name eq "Bos taurus" and $name =~ /scaffold(\d+)/) {
    $name = "ChrUn.$1"; # cow scaffold in ensembl are called ChrUn.XXXXX
  }
  if ($genome_db->{$species}->name eq "Bos taurus" and $name eq "X") {
    $name = "30"; # cow chr.30 is named chr.X in UCSC
  }

  my $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($genome_db->{$species}, $name);
  if (!$dnafrag) {

    my ($seq_region_start, $seq_region_end);
    if ($strand == -1) {
      $seq_region_start = $seq_region_length-($start_pos + $length - 1);
      $seq_region_end = $seq_region_length-($start_pos);
    } else {
      $seq_region_start = $start_pos + 1;
      $seq_region_end = $start_pos + $length;
    }
    ## This chromosome does not exist in EnsEMBL, we have to map it using the golden path
    if (!defined($dnafrag_mapper->{"${species}_${name}"})) {
      $dnafrag_mapper->{"${species}_${name}"} = get_this_dnafrag_mapper($species, $name);
    }

    if (!$dnafrag_mapper->{"${species}_${name}"}) {
      ## File does not exist. 
      ($dnafrag, $dnafrag_start, $dnafrag_end, $dnafrag_strand) = map_on_toplevel($species,
          $name, $seq_region_start, $seq_region_end, $strand);
    } else {
      my @mapped_objects = $dnafrag_mapper->{"${species}_${name}"}->map_coordinates(
              $name,
              $seq_region_start,
              $seq_region_end,
              $strand,
              'chromosome');
      if (scalar(@mapped_objects) == 1 and $mapped_objects[0]->isa("Bio::EnsEMBL::Mapper::Coordinate")) {

        $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name(
                $genome_db->{$species},
                $mapped_objects[0]->id
            );
        if (!$dnafrag) {
          ## DnaFrags are not in the compara DB. Try to project on toplevel coord system
          ($dnafrag, $dnafrag_start, $dnafrag_end, $dnafrag_strand) = map_on_toplevel($species,
              $mapped_objects[0]->id, $mapped_objects[0]->start, $mapped_objects[0]->end,
              $mapped_objects[0]->strand);
          if (!$dnafrag) {
            $all_warnings{"Mapping $species.".$mapped_objects[0]->id. " on $species.chr$name"}++;
            $malign_warning .= "- $species.chr$name (".$mapped_objects[0]->id.") -";
            return undef;
          }
        } else {
          $dnafrag_start = $mapped_objects[0]->start;
          $dnafrag_end = $mapped_objects[0]->end;
        }
      }
    }
  } else {
    $dnafrag_strand = $strand;
    if ($strand == 1) {
      $dnafrag_start = $start_pos + 1;
      $dnafrag_end = $start_pos + $length;
    } elsif ($strand == -1) {
      $dnafrag_start = $dnafrag->length - $start_pos - $length + 1;
      $dnafrag_end = $dnafrag->length - $start_pos;
    } else {
      throw("Cannot understand strand $strand");
    }
  }
  ## Deal with unknown dnafrags
  if (!$dnafrag) {
    $print_multiple_alignment =~ s/\n$/  **NOT AVAILABLE**\n/;;
    if ($force) {
      print "IGNORING: Chromosome $species.chr$name\n";
      $all_warnings{"Chromosome $species.chr$name"}++;
      return undef;
    } elsif ($skip) {
      $all_warnings{"Chromosome $species.chr$name"}++;
      $malign_warning .= "- $species.chr$name -";
      return undef;
    } else {
      throw ("Cannot fetch DnaFrag for ".$ucsc_2_ensembl->{$species}->{'name'}.", chromosome $name\n".
          $print_multiple_alignment);
    }
  }
    
  my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign (
          -adaptor => $genomic_align_adaptor,
          -dnafrag => $dnafrag,
          -dnafrag_start => $dnafrag_start,
          -dnafrag_end => $dnafrag_end,
          -dnafrag_strand => $dnafrag_strand,
          -aligned_sequence => $aligned_sequence,
          -group_id => 0,
          -level_id => 1
      );

  return $genomic_align;
}


=head2 get_this_dnafrag_mapper

 Arg[1]      : string $short_UCSC_species_name
 Arg[2]      : string $chromosome_name
 Example     : get_this_dnafrag_mapper("galGal2", "chrX");
 Description : This function reads the golden path file corresponding to this
               species and creates a Bio::EnsEMBL::Mapper object with this
               assembly
 ReturnType  : Bio::EnsEMBL::Mapper object
 Exception   : return undef if file cannot be opened
 Exception   : return undef if file is not understood
 Caller      : methodname

=cut

sub get_this_dnafrag_mapper {
  my ($species, $name) = @_;
  my $dnafrag_mapper;

  open(GOLD, "$multiz_dir/${species}_gold.txt") or return undef;
  $dnafrag_mapper = new Bio::EnsEMBL::Mapper('frag', 'chromosome');
  while (<GOLD>) {
    next if (/^#/);
    if (!/^\d+\s+(\S+)\s+(\d+)\s+(\d+)\s+\d+\s+\w\s+(\S+)\s+(\d+)\s+(\d+)\s+([\-|\+|\.])$/) {
      throw ("Wrong File format: $multiz_dir/${species}_gold.txt\n$_\n");
      return undef;
    }
    my ($chr, $chr_start, $chr_end, $frag, $frag_start, $frag_end, $frag_strand) =
        ($1, $2, $3, $4, $5, $6, $7);
    $frag_strand = "+" if ($frag_strand ne "-");
    $chr =~ s/^chr//;
    next if ($chr ne $name);
    if (($frag_end - $frag_start + 1) == ($chr_end - $chr_start)) {
      $frag_start--;
    }
    $dnafrag_mapper->add_map_coordinates(
            $frag, $frag_start+1, $frag_end, $frag_strand."1",
            $chr, $chr_start+1, $chr_end);
  }
  close(GOLD);

  return $dnafrag_mapper;
}


=head2 map_on_top_level


=cut

sub map_on_toplevel {
  my ($species, $seq_region_name, $start, $end, $strand) = @_;
  my ($dnafrag, $dnafrag_start, $dnafrag_end, $dnafrag_strand);

  my $slice_adaptor = $genome_db->{$species}->db_adaptor->get_SliceAdaptor;
  my $slice = ($slice_adaptor->fetch_by_region(undef, $seq_region_name, $start, $end, $strand)
          or $slice_adaptor->fetch_by_region(undef, $seq_region_name.".1", $start, $end, $strand));
  return ($dnafrag, $dnafrag_start, $dnafrag_end, $dnafrag_strand) if (!$slice);
  my $projection_segments;
  $projection_segments = $slice->project('toplevel') if (defined($slice));
  if ($projection_segments and scalar(@$projection_segments) == 1) {
    my $projected_start = $projection_segments->[0]->from_start;
    my $projected_end = $projection_segments->[0]->from_end;
    my $projected_slice = $projection_segments->[0]->to_Slice;
    $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name(
            $genome_db->{$species},
            $projected_slice->seq_region_name
        );
    $dnafrag_start = $start + $projected_slice->start - $projected_start;
    $dnafrag_end = $end + $projected_slice->end - $projected_end;
    $dnafrag_strand = $projected_slice->strand;
  }

  return ($dnafrag, $dnafrag_start, $dnafrag_end, $dnafrag_strand);
}

