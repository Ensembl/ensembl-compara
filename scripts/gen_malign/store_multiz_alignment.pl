#!/usr/local/ensembl/bin/perl

my $description = q{
###############################################################################
##
##  PROGRAM store_multiz_alignment.pl
##
##  AUTHOR Javier Herrero (jherrero@ebi.ac.uk)
##
##    This software is part of the EnsEMBL project.
##
##  DESCRIPTION: This program reads a multiz file and stores all the
##    alignments into the selected database.
##
###############################################################################

};

=head1 NAME

store_multiz_alignment.pl

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This software is part of the EnsEMBL project.

=head1 DESCRIPTION

This program reads a multiz file and stores all the alignments into the
selected database.

=head1 USAGE

store_multiz_alignment.pl [-help]
  -host mysql_host_server (for ensembl_compara DB)
  -dbuser db_username (default = 'ensro')
  -dbname ensembl_compara_database
  -port mysql_host_port (default = 3352)
  -conf_file compara_conf_file
      see an example in ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf.example
  -multiz_file file_containing_multiz_alignemnts
  -skip (ignores unknown genome assemblies and skips the whole alignment)
  -force (ignores unknown genome assemblies but stores the remaining sequences of the aligment)
  -score minimum_score_threhold (default No minimum)
  -min_seq minimum_number_of_sequences_in_the_multiple_alignment (default No minimum)

store_multiz_alignment.pl [-help]
  -host mysql_host_server (for ensembl_compara DB)
  -dbuser db_username (default = 'root')
  -dbname ensembl_compara_database
  -port mysql_host_port (default = 3303)
  -mavid directory_containing_mavid_alignemnts_and_map_file

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
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw( throw warning info );
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Utils::Exception qw( verbose );
use Getopt::Long;

#verbose("INFO");

###############################################################################
##  CONFIGURATION VARIABLES:
##   (*) $ucsc_2_ensembl:  maps the UCSC species names into the EnseEMBL
##           species naming system.
###############################################################################
my $ucsc_2_ensembl = {
      "hg16"    => {'name' => "Homo sapiens", 'assembly' => "NCBI34"},
      "hg17"    => {'name' => "Homo sapiens", 'assembly' => "NCBI35"},
      "mm3"     => {'name' => "Mus musculus", 'assembly' => "NCBIM32"},
      "mm5"     => {'name' => "Mus musculus", 'assembly' => "NCBIM33"},
      "rn3"     => {'name' => "Rattus norvegicus", 'assembly' => "RGSC3.1"},
      "galGal2" => {'name' => "Gallus gallus", 'assembly' => "WASHUC1"},
      "panTro1" => {'name' => "Pan troglodytes", 'assembly' => "CHIMP1"},
      "canFam1" => {'name' => "Canis familiaris", 'assembly' => "BROADD1"},
      "fr1"     => {'name' => "Fugu rubripes", 'assembly' => "FUGU2"},
      "danRer1"     => {'name' => "Danio rerio", 'assembly' => "ZFISH3"},

      "hg16" => {'name' => "Homo sapiens", 'assembly' => "NCBI34"},
      "hg17" => {'name' => "Homo sapiens", 'assembly' => "NCBI35"},
      "Mm3"  => {'name' => "Mus musculus", 'assembly' => "NCBIM32"},
      "Mm5"  => {'name' => "Mus musculus", 'assembly' => "NCBIM33"},
      "Rn3"  => {'name' => "Rattus norvegicus", 'assembly' => "RGSC3.1"},
      "Gg2" => {'name' => "Gallus gallus", 'assembly' => "WASHUC1"},
      "Pt1" => {'name' => "Pan troglodytes", 'assembly' => "CHIMP1"},
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
  );

if ($help) {
  print $description, $usage;
  exit(0);
}

Bio::EnsEMBL::Registry->load_all($reg_conf);

if (!$multiz_dir or !opendir(MULTIZ_DIR, $multiz_dir)) {
  print "ERROR: Cannot open <$multiz_dir> directory!\n", $usage;
  exit(1);
}
my @multiz_files = grep { /\.maf/ } readdir(MULTIZ_DIR);
closedir(MULTIZ_DIR);

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
  $genome_db->{$this_species} = eval{$genome_db_adaptor->fetch_by_name_assembly(
      $ucsc_2_ensembl->{$this_species}->{'name'},
      $ucsc_2_ensembl->{$this_species}->{'assembly'}
      );};
  if (!$genome_db->{$this_species}) {
    warning("Assembly ".$ucsc_2_ensembl->{$this_species}->{'assembly'}." of species [$this_species] is not loaded!");
    print "Do you want to continue with the remaining speceis? ";
    my $resp = <STDIN>;
    next if ($resp =~ /^y/i);
    exit(1);
  }
  push (@$species_set, $genome_db->{$this_species});
}

my $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -adaptor => $method_link_species_set_adaptor,
        -method_link_type => "MULTIZ",
        -species_set => $species_set
    );
$method_link_species_set = $method_link_species_set_adaptor->store($method_link_species_set);

foreach my $multiz_file (@multiz_files) {
  my @all_these_genomic_aligns; # array of Bio::EnsEMBL::Compara::GenomicAlign objects to store as a single multiple alignment

  if ($multiz_file =~ /\.gz$/) {
    open(MULTIZ, "gunzip -c $multiz_dir/$multiz_file |") || die;
  } elsif ($multiz_file =~ /\.bz2$/) {
    open(MULTIZ, "bzcat $multiz_dir/$multiz_file |");
  } else {
    open(MULTIZ, $multiz_dir/$multiz_file);
  }

  while (<MULTIZ>) {
    ## For all lines that are not "s" lines (parts of the multiple alignment)
    if (!/^s\s+([^\.]+)\.chr(\S+)\s+(\d+)\s+(\d+)\s+([\+\-])\s+\d+\s+(.+)$/) {
      
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
    my $aligned_sequence = $6;
    
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
    
    my $dnafrag;
    if (defined($genome_db->{$species})) {
      $dnafrag = get_this_dnafrag($genome_db->{$species}, undef, $chromosome);
    }

    ## Deal with unknown dnafrags
    if (!$dnafrag) {
      $print_multiple_alignment =~ s/\n$/  **NOT AVAILABLE**\n/;;
      if ($force) {
        print "IGNORING: Chromosome $species.chr$chromosome\n";
        $all_warnings{"Chromosome $species.chr$chromosome"}++;
        next;
      } elsif ($skip) {
        $all_warnings{"Chromosome $species.chr$chromosome"}++;
        $malign_warning .= "- $species.chr$chromosome (".$all_warnings{"Chromosome $species.chr$chromosome"}.")-";
        next;
      } else {
        throw ("Cannot fetch DnaFrag for ".$ucsc_2_ensembl->{$species}->{'name'}.", chromosome $chromosome\n".
            $print_multiple_alignment);
      }
    }
    
    my ($dnafrag_start, $dnafrag_end);
    if ($strand == 1) {
      $dnafrag_start = $start_pos + 1;
      $dnafrag_end = $start_pos + $length;
    } elsif ($strand == -1) {
      $dnafrag_start = $dnafrag->length - $start_pos - $length + 1;
      $dnafrag_end = $dnafrag->length - $start_pos;
    } else {
      throw("Cannot understand strand $strand");
    }

    my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign (
            -adaptor => $genomic_align_adaptor,
            -dnafrag => $dnafrag,
            -dnafrag_start => $dnafrag_start,
            -dnafrag_end => $dnafrag_end,
            -dnafrag_strand => $strand,
            -aligned_sequence => $aligned_sequence,
            -group_id => 0,
            -level_id => 1
        );

    if ($check_sequences) {
      my $db_sequence = uc($genomic_align->dnafrag->slice->subseq(
              $genomic_align->dnafrag_start,
              $genomic_align->dnafrag_end,
              $genomic_align->dnafrag_strand
          ));
      my $multiz_sequence = uc($genomic_align->original_sequence);
      if ($db_sequence ne $multiz_sequence) {
        my $err_str = 
            "Error while retrieving sequence ".
            $ucsc_2_ensembl->{$species}->{'name'}.
            ", chromosome $chromosome [". $dnafrag_start. "-". $dnafrag_end. "] ".
            (($strand == 1)?"(+)":"(-)")." -- (MULTIZ start:$start_pos length:$length\n".
            " DATABS: ". substr($db_sequence, 0, 10). "..".
            substr($db_sequence, -11). "\n".
            " MULTIZ: ". substr($multiz_sequence, 0, 10). "..".
            substr($multiz_sequence, -11);
        throw $err_str;
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

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
               The GenomeDB object corresponding to this dnafrag.
  Arg[2]     : string $fragment_type
  Arg[3]     : string $fragment_name
  Example    : get_this_danfrag($human_db, 'chromosome', '17');
  Description: Returns the corresponding DnaFrag object.
  Returntype : Bio::EnsEMBL::Compara::DnaFrag
  Exceptions : returns undef when the DnaFrag does not exist in the database.

=cut

sub get_this_dnafrag {
  my ($genome_db, $fragment_type, $fragment_name) = @_;

  my $dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region($genome_db, $fragment_type, $fragment_name);
  my $dnafrag = undef;
  foreach my $this_dnafrag (@$dnafrags) {
    if ((!defined($fragment_type) or ($this_dnafrag->coord_system_name eq $fragment_type))
        and $this_dnafrag->name eq $fragment_name) {
      $dnafrag = $this_dnafrag;
      last;
    }
  }
  
  #returns null if the dnafrag does not exist in the database
  return $dnafrag;
}

