#!/usr/local/ensembl/bin/perl -w

my $description = q{
###########################################################################
##
## PROGRAM DumpFakeMultiAlign.pl
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

DumpFakeMultiAlign.pl

=head1 AUTHORS

 Abel Ureta-Vidal (abel@ebi.ac.uk)
 Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

This script is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script dumps pairwise genomic alignments from an EnsEMBL Compara Database and
creates a fake multiple alignment from them. For example, it takes human-mouse, human-rat
and human-dog MULTIZ_NET alignments and builds a fake multiple alignment on a piece of
human genomic sequence.

=head1 SYNOPSIS

perl DumpFakeMultiAlign.pl --species human --seq_region 14 --seq_region_start 75000000
    --seq_region_end 75010000 --alignment_type BLASTZ_NET --set_of_species mouse:rat:dog

perl DumpFakeMultiAlign.pl
    [--reg_conf registry_configuration_file]
    [--dbname compara_db_name]
    [--species query_species]
    [--coord_system coordinates_name]
    --seq_region region_name
    --seq_region_start start
    --seq_region_end end
    [--alignment_type method_link_name]
    [--set_of_species species1:species2:species3:...]
    [--output_format clustalw|fasta|...]
    [--[no]project_on_query]
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

=back

=head2 OUTPUT

=over

=item B<[--output_format clustalw|fasta|...]>
  
The type of output you want. "clustalw" is the default.

=item B<[--[no]project_on_query]>
  
By default the fake genomic alignments are returned in logical units. This flag allows you
to project the result on the query seq_region.

=item B<[--output_file filename]>
  
The name of the output file. By default the output is the
standard output

=back

=cut

my $usage = qq{
perl DumpFakeMultiAlign.pl
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

  For the alignments:
    [--alignment_type method_link_name]
        The type of alignment. Default is "BLASTZ_NET"
    [--set_of_species species1:species2:species3:...]
        The list of other species used to fetch original pairwise alignments
        and build fake multiple one. Default is "mouse:rat". The names
        should correspond to the name of the core database in the
        registry_configuration_file or any of its aliases

  Ouput:
    [--[no]project_on_query]
        By default, fake multiple alignments overlapping or partially
        overlapping the query sequence are returned. This flag allows
        you to project the alignments on the query sequence: 1 single
        large multiple alignment will be returned.
    [--output_format clustalw|fasta|...]
        The type of output you want. "clustalw" is the default.
    [--[no]project_on_query]
        By default the fake genomic alignments are returned in logical units.
        This flag allows you to project the result on the query seq_region.
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

my $reg_conf;
my $dbname = "compara";
my $query_species = "human";
my $coord_system = "chromosome";
my $seq_region = "14";
my $seq_region_start = 75007000;
my $seq_region_end = 75008000;
my $alignment_type = "BLASTZ_NET";
my $set_of_species = "mouse:rat";
my $output_file = undef;
my $output_format = "clustalw";
my $project_on_query = 0;
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
    "alignment_type=s" => \$alignment_type,
    "set_of_species=s" => \$set_of_species,
    "project_on_query!" => \$project_on_query,
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
my $query_slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region, $seq_region_start, $seq_region_end);
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
    
## Get all the GenomicAlign objects for the other species corresponding to the query_slice
my $all_genomic_align_blocks = [];
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
        $dbname,
        'compara',
        'MethodLinkSpeciesSet'
    );
my $genomic_align_block_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
        $dbname,
        'compara',
        'GenomicAlignBlock'
    );
foreach my $this_species (split(":", $set_of_species)) {
  my $genome_dbs;
  my $method_link_species_set = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs(
        $alignment_type, [$genome_db->{$query_species}, $genome_db->{$this_species}]);
  throw("The database does not contain any $alignment_type data for $query_species and $this_species!")
      if (!$method_link_species_set);
  push(@$all_genomic_align_blocks,
      @{$genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice(
          $method_link_species_set, $query_slice)});
}

##############################################################################################
##
## Compile GenomicAlignBlocks in group of GenomicAlignBlocks based on reference coordinates
##
my $sets_of_genomic_align_blocks = [];
my $start_pos;
my $end_pos;
my $this_set_of_genomic_align_blocks = [];
foreach my $this_genomic_align_block (sort {$a->reference_genomic_align->dnafrag_start <=>
        $b->reference_genomic_align->dnafrag_start} @$all_genomic_align_blocks) {
  my $this_start_pos = $this_genomic_align_block->reference_genomic_align->dnafrag_start;
  my $this_end_pos = $this_genomic_align_block->reference_genomic_align->dnafrag_end;
  if (defined($end_pos) and ($this_start_pos <= $end_pos)) {
    # this genomic_align_block overlaps previous one. Extend this set_of_coordinates
    $end_pos = $this_end_pos if ($this_end_pos > $end_pos);
  } else {
    # there is a gap between this genomic_align_block and the previous one. Close and save
    # this set_of_genomic_align_blocks (if it exists) and start a new one.
    push(@{$sets_of_genomic_align_blocks}, [$start_pos, $end_pos, $this_set_of_genomic_align_blocks])
        if (defined(@$this_set_of_genomic_align_blocks));
    $start_pos = $this_start_pos;
    $end_pos = $this_end_pos;
    $this_set_of_genomic_align_blocks = [];
  }
  push(@$this_set_of_genomic_align_blocks, $this_genomic_align_block);
}
push(@{$sets_of_genomic_align_blocks}, [$start_pos, $end_pos, $this_set_of_genomic_align_blocks])
      if (defined(@$this_set_of_genomic_align_blocks));
##
##############################################################################################


my $fake_genomic_align_blocks = [];
foreach my $this_set_of_genomic_align_blocks (@$sets_of_genomic_align_blocks) {
  my $this_fake_genomic_align_block = compile_fake_genomic_align2(@$this_set_of_genomic_align_blocks);
  push(@{$fake_genomic_align_blocks}, $this_fake_genomic_align_block);
}

my $all_aligns;
if ($project_on_query) {

  ## Create an AlignSlice for projecting on query_slice
  my $align_slice = new Bio::EnsEMBL::Compara::AlignSlice(
          -REFERENCE_SLICE => $query_slice,
          -GENOMIC_ALIGN_BLOCKS => $fake_genomic_align_blocks
      );
  my $simple_align = $align_slice->get_projected_SimpleAlign;
  push(@$all_aligns, $simple_align);

} else {
  ### Build Bio::SimpleAlign objects
  foreach my $this_genomic_align_block (@$fake_genomic_align_blocks) {
    my $simple_align = Bio::SimpleAlign->new();
    $simple_align->id("FakeMultiAlign(".$this_genomic_align_block->reference_genomic_align->display_id);
  
    my $count = 0;
  #   foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_GenomicAligns}) {
  #     print $this_genomic_align->cigar_line, "\n";
  #   }
    foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_GenomicAligns}) {
      my $seq_name = $this_genomic_align->dnafrag->genome_db->name;
      $seq_name =~ s/(.)\w* (.)\w*/$1$2/;
      $seq_name .= $this_genomic_align->dnafrag->name.".".(++$count);
      my $aligned_sequence = $this_genomic_align->aligned_sequence;
      my $seq = Bio::LocatableSeq->new(
              -SEQ    => $aligned_sequence,
              -START  => $this_genomic_align->dnafrag_start,
              -END    => $this_genomic_align->dnafrag_end,
              -ID     => $seq_name,
              -STRAND => $this_genomic_align->dnafrag_strand
          );
      $simple_align->add_seq($seq);
    }
    push(@$all_aligns, $simple_align);
  }
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

exit();


=head2 compile_fake_genomic_align

  Arg [1]     : integer $start_pos (the start of the fake genomic_align)
  Arg [2]     : integer $end_pos (the end of the fake genomic_align)
  Arg [3]     : listref of Bio::EnsEMBL::Compara::GenomicAlignBlocks $set_of_genomic_align_blocks
                $all_genomic_align_blocks (the pairwise genomic_align_blocks used for
                this fake multiple genomic_aling_block)
  Example     : 
  Description : 
  Returntype  : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions  : 
  Caller      : methodname

=cut

sub compile_fake_genomic_align2 {
  my ($start_pos, $end_pos, $all_genomic_align_blocks) = @_;

  ############################################################################################
  ##
  ## Change strands in order to have all reference genomic aligns on the forward strand
  ##
  foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
    my $this_genomic_align = $this_genomic_align_block->reference_genomic_align;
    if ($this_genomic_align->dnafrag_strand == -1) {
      foreach my $genomic_align (@{$this_genomic_align_block->genomic_align_array}) {
        $genomic_align->reverse_complement;
      }
    }
  }
  ##
  ############################################################################################

  ############################################################################################
  ##
  ## Fix all sequences
  ##
  foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
    my $this_genomic_align = $this_genomic_align_block->reference_genomic_align;
    my $this_start_pos = $this_genomic_align->dnafrag_start;
    my $this_end_pos = $this_genomic_align->dnafrag_end;
    my $starting_gap = $this_start_pos - $start_pos;
    my $ending_gap = $end_pos - $this_end_pos;
  
    my $this_cigar_line = $this_genomic_align->cigar_line;
    my $this_original_sequence = $this_genomic_align->original_sequence;
    $this_genomic_align->aligned_sequence("");
    if ($starting_gap) {
      $this_cigar_line = $starting_gap."M".$this_cigar_line;
      $this_original_sequence = ("N" x $starting_gap).$this_original_sequence;
    }
    if ($ending_gap) {
      $this_cigar_line .= $ending_gap."M";
      $this_original_sequence .= ("N" x $ending_gap);
    }
    $this_genomic_align->cigar_line($this_cigar_line);
    $this_genomic_align->original_sequence($this_original_sequence);
    
    foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_non_reference_genomic_aligns}) {
      $this_genomic_align->aligned_sequence("");
      my $this_cigar_line = $this_genomic_align->cigar_line;
      $this_cigar_line = $starting_gap."D".$this_cigar_line if ($starting_gap);
      $this_cigar_line .= $ending_gap."D" if ($ending_gap);
      $this_genomic_align->cigar_line($this_cigar_line);
      $this_genomic_align->aligned_sequence(); # compute aligned_sequence using cigar_line
    }
  }
  ##
  ############################################################################################

  ############################################################################################
  ##
  ## Distribute gaps
  ##
  my $aln_pos = 0;
  my $gap;
  do {
    my $gap_pos;
    my $genomic_align_block_id;
    $gap = undef;

    ## Get the (next) first gap from all the alignments (sets: $gap_pos, $gap and $genomic_align_block_id)
    foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
      my $this_gap_pos = index($this_genomic_align_block->reference_genomic_align->aligned_sequence, "-", $aln_pos);
      if ($this_gap_pos > 0 and (!defined($gap_pos) or $this_gap_pos < $gap_pos)) {
        $gap_pos = $this_gap_pos;
        my $gap_string = substr($this_genomic_align_block->reference_genomic_align->aligned_sequence, $gap_pos);
        ($gap) = $gap_string =~ /^(\-+)/;
        $genomic_align_block_id = $this_genomic_align_block->dbID;
      }
    }

    ## If a gap has been found, apply it to the other GAB
    if ($gap) {
      $aln_pos = $gap_pos + length($gap);
      foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
        next if ($genomic_align_block_id == $this_genomic_align_block->dbID); # Do not add gap to itself!!
        foreach my $this_genomic_align (@{$this_genomic_align_block->genomic_align_array}) {
          # insert gap in the aligned_sequence
          my $aligned_sequence = $this_genomic_align->aligned_sequence;
          substr($aligned_sequence, $gap_pos, 0, $gap);
          $this_genomic_align->aligned_sequence($aligned_sequence);
        }
      }
    }
    
  } while ($gap); # exit loop if no gap has been found

  ## Fix all cigar_lines in order to match new aligned_sequences
  foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
    foreach my $this_genomic_align (@{$this_genomic_align_block->genomic_align_array}) {
      $this_genomic_align->cigar_line(""); # undef old cigar_line
      $this_genomic_align->cigar_line(); # compute cigar_line from aligned_sequence
    }
  }
  ##
  ############################################################################################

  ############################################################################################
  ##
  ##  Create the reference_genomic_align for this fake genomic_align_block
  ##
  my $reference_genomic_align;
  if (@$all_genomic_align_blocks) {
    my $this_genomic_align = $all_genomic_align_blocks->[0]->reference_genomic_align;
    $reference_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
            -dbID => -1,
            -dnafrag => $this_genomic_align->dnafrag,
            -dnafrag_start => $start_pos,
            -dnafrag_end => $end_pos,
            -dnafrag_strand => 1,
            -cigar_line => $this_genomic_align->cigar_line
        );
  }
  ##
  ############################################################################################

  
  ## Create the genomic_align_array (the list of genomic_aling for this fake gab
  my $genomic_align_array = [$reference_genomic_align];
  foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
    foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_non_reference_genomic_aligns}) {
      $this_genomic_align->genomic_align_block_id(0); # undef old genomic_align_block_id
      push(@$genomic_align_array, $this_genomic_align);
    }
  }
  
  ## Create the fake multiple Bio::EnsEMBL::Compara::GenomicAlignBlock
  my $fake_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -length => ($end_pos - $start_pos + 1),
          -genomic_align_array => $genomic_align_array,
          -reference_genomic_align => $reference_genomic_align,
      );
  
  return $fake_genomic_align_block;
}


# # 
# # OLD SLOW AND MESSY VERSION
# # 
# # sub compile_fake_genomic_align1 {
# #   my ($start_pos, $end_pos, $all_genomic_align_blocks) = @_;
# # 
# #   ############################################################################################
# #   ##
# #   ## Change strands in order to have all reference genomic aligns on the forward strand
# #   ##
# #   foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
# #     my $this_genomic_align = $this_genomic_align_block->reference_genomic_align;
# #     if ($this_genomic_align->dnafrag_strand == -1) {
# #       foreach my $genomic_align (@{$this_genomic_align_block->genomic_align_array}) {
# #         $genomic_align->reverse_complement;
# #       }
# #     }
# #   }
# #   ##
# #   ############################################################################################
# # 
# #   ############################################################################################
# #   ##
# #   ## Get the coordinates of all the gaps in all the reference genomic align. Every
# #   ## gap_insertion is a hash of $gap_insertion->{GAB_ID} = genomic_align_block_id and
# #   ## $gap_insertion->{COORDINATES} = [$start_of_gap, $gap_length]. Gaps are on
# #   ## original_sequence coordinates
# #   ##
# #   my $all_gap_insertions = get_all_gap_insertions_from_genomic_align_blocks(
# #       $all_genomic_align_blocks, $start_pos, $end_pos);
# #   ##
# #   ############################################################################################
# #   
# #   ############################################################################################
# #   ##
# #   ##  Create the reference_genomic_align for this fake genomic_align_block
# #   ##
# #   my $reference_genomic_align;
# #   my $fake_cigar_line = get_cigar_line_from_all_gap_insertions(
# #           $all_gap_insertions,
# #           ($end_pos - $start_pos + 1)
# #       );
# #   if (@$all_genomic_align_blocks) {
# #     my $this_genomic_align = $all_genomic_align_blocks->[0]->reference_genomic_align;
# #     $reference_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
# #             -dbID => -1,
# #             -dnafrag => $this_genomic_align->dnafrag,
# #             -dnafrag_start => $start_pos,
# #             -dnafrag_end => $end_pos,
# #             -dnafrag_strand => 1,
# #             -cigar_line => $fake_cigar_line
# #         );
# #   }
# #   ##
# #   ############################################################################################
# # 
# #   
# #   ## Fix reference sequences
# #   foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
# #     fix_reference_sequence($this_genomic_align_block, $start_pos, $end_pos);
# #   }
# # 
# #   my $gap_inserted_at;
# #   foreach my $this_gap_insertions (sort {$a->{COORDINATES}->[0] <=> $b->{COORDINATES}->[0]} @$all_gap_insertions) {
# #     my $these_gap_coordinates = $this_gap_insertions->{COORDINATES};
# #     my $start_coord = $these_gap_coordinates->[0];
# #     my $gap_length = $these_gap_coordinates->[1];
# #     my $original_aln_start;
# # 
# #     foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
# #       next if ($this_genomic_align_block->dbID == $this_gap_insertions->{GAB_ID});
# # 
# #       my $this_genomic_align = $this_genomic_align_block->reference_genomic_align;
# #       my $this_start_pos = $this_genomic_align->dnafrag_start;
# #       my $starting_gap = $this_start_pos - $start_pos;
# #       my $this_cigar_line = $this_genomic_align->cigar_line;
# # 
# #       my $aln_start;
# #       ($this_cigar_line, $aln_start) = insert_gap_in_cigar_line($this_cigar_line, $start_coord, $gap_length);
# #       $this_genomic_align->cigar_line($this_cigar_line);
# # 
# #       if (defined($original_aln_start)) {
# #         throw("WRONG ALIGNMENT_START!") if ($original_aln_start != $aln_start);
# #       } else {
# #         $original_aln_start = $aln_start;
# #       }
# # 
# #       $aln_start += $gap_inserted_at->{$original_aln_start} if (defined($gap_inserted_at->{$original_aln_start}));
# #       $aln_start -= $starting_gap;
# #       $aln_start = 0 if ($aln_start<0);
# # 
# #       foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_non_reference_genomic_aligns}) {
# #         my $aligned_sequence = $this_genomic_align->aligned_sequence;
# #         $aln_start = length($aligned_sequence) if ($aln_start>length($aligned_sequence));
# #         substr($aligned_sequence, $aln_start, 0, "-"x$gap_length);
# #         $this_genomic_align->aligned_sequence($aligned_sequence);
# #       }
# #     }
# #     $gap_inserted_at->{$original_aln_start} += $gap_length if (defined($original_aln_start));
# #   }
# #   
# #   ## Fix non-reference sequences
# #   foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
# #     fix_all_non_reference_sequences($this_genomic_align_block, $start_pos, $end_pos);
# #   }
# # 
# #   ## Create the genomic_align_array (the list of genomic_align for this fake gab
# #   my $genomic_align_array = [$reference_genomic_align];
# #   foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
# #     my $this_start_pos = $this_genomic_align_block->reference_genomic_align->dnafrag_start;
# #     my $this_end_pos = $this_genomic_align_block->reference_genomic_align->dnafrag_end;
# #     my $starting_gap = $this_start_pos - $start_pos;
# #     my $ending_gap = $end_pos - $this_end_pos;
# # 
# #     foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_non_reference_genomic_aligns}) {
# #       my $cigar_line = $this_genomic_align->cigar_line;
# #       
# #       $this_genomic_align->genomic_align_block_id(0);
# #       $this_genomic_align->aligned_sequence("");
# #       push(@$genomic_align_array, $this_genomic_align);
# #     }
# #   }
# #   
# #   ## Create the fake multiple Bio::EnsEMBL::Compara::GenomicAlignBlock
# #   my $fake_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
# #           -length => ($end_pos - $start_pos + 1),
# #           -genomic_align_array => $genomic_align_array,
# #           -reference_genomic_align => $reference_genomic_align,
# #       );
# #   
# #   return $fake_genomic_align_block;
# # }
# # 
# # 
# # sub fix_reference_sequence {
# #   my ($this_genomic_align_block, $start_pos, $end_pos) = @_;
# #     
# #   my $this_genomic_align = $this_genomic_align_block->reference_genomic_align;
# #   my $this_start_pos = $this_genomic_align->dnafrag_start;
# #   my $this_end_pos = $this_genomic_align->dnafrag_end;
# #   my $starting_gap = $this_start_pos - $start_pos;
# #   my $ending_gap = $end_pos - $this_end_pos;
# # 
# #   my $this_cigar_line = $this_genomic_align->cigar_line;
# #   my $this_original_sequence = $this_genomic_align->original_sequence;
# #   $this_genomic_align->aligned_sequence("");
# #   if ($starting_gap) {
# #     $this_cigar_line = $starting_gap."M".$this_cigar_line;
# #     $this_original_sequence = ("N" x $starting_gap).$this_original_sequence;
# #   }
# #   if ($ending_gap) {
# #     $this_cigar_line .= $ending_gap."M";
# #     $this_original_sequence .= ("N" x $ending_gap);
# #   }
# #   $this_genomic_align->cigar_line($this_cigar_line);
# #   $this_genomic_align->original_sequence($this_original_sequence);
# # }
# # 
# # 
# # sub fix_all_non_reference_sequences {
# #   my ($this_genomic_align_block, $start_pos, $end_pos) = @_;
# #     
# #   my $this_start_pos = $this_genomic_align_block->reference_genomic_align->dnafrag_start;
# #   my $this_end_pos = $this_genomic_align_block->reference_genomic_align->dnafrag_end;
# #   my $starting_gap = $this_start_pos - $start_pos;
# #   my $ending_gap = $end_pos - $this_end_pos;
# # 
# #   foreach my $this_genomic_align (@{$this_genomic_align_block->get_all_non_reference_genomic_aligns}) {
# #     $this_genomic_align->cigar_line(""); # undef cigar_line
# #     my $this_cigar_line = $this_genomic_align->cigar_line; # get cigar_line from aligned_sequence
# #     $this_cigar_line = $starting_gap."D".$this_cigar_line if ($starting_gap);
# #     $this_cigar_line .= $ending_gap."D" if ($ending_gap);
# #     $this_genomic_align->cigar_line($this_cigar_line);
# #   }
# # }
# # 
# # 
# # sub insert_gap_in_cigar_line {
# #   my ($cigar_line, $start, $gap_length) = @_;
# #   my $modified_cigar_line = "";
# #   my $seq_pos = 0;
# #   my $aln_pos = 0;
# #   my $aln_pos_of_insertion = 0;
# # 
# #   my @cig = ( $cigar_line =~ /(\d*[GMD])/g );
# #   while (my $cigElem = shift(@cig)) {
# #     my $cigType = substr( $cigElem, -1, 1 );
# #     my $cigCount = substr( $cigElem, 0 ,-1 );
# #     $cigCount = 1 unless $cigCount;
# # 
# #     if( $cigType eq "M" ) {
# #       if ($start <= ($seq_pos + $cigCount) and $start > $seq_pos) {
# #         $aln_pos_of_insertion = $aln_pos;
# #         $aln_pos_of_insertion += ($start - $seq_pos) if ($start - $seq_pos > 0);
# #         $modified_cigar_line .= ($start - $seq_pos)."M" if ($start - $seq_pos > 0);
# #         $modified_cigar_line .= $gap_length."D";
# #         $modified_cigar_line .= ($cigCount + $seq_pos - $start)."M" if ($cigCount + $seq_pos - $start > 0);
# #       } else {
# #         $modified_cigar_line .= $cigElem;
# #       }
# #       $seq_pos += $cigCount;
# #     } else {
# #       $modified_cigar_line .= $cigElem;
# #     }
# #     $aln_pos += $cigCount;
# #   }
# # 
# #   return ($modified_cigar_line, $aln_pos_of_insertion, $gap_length);
# # }
# # 
# # 
# # sub get_all_gap_insertions_from_genomic_align_blocks {
# #   my ($all_genomic_align_blocks, $start_pos, $end_pos) = @_;
# # 
# #   my $all_gap_insertions = [];
# #   foreach my $this_genomic_align_block (@$all_genomic_align_blocks) {
# # 
# # 
# #     my $this_start_pos = $this_genomic_align_block->reference_genomic_align->dnafrag_start;
# #     my $this_end_pos = $this_genomic_align_block->reference_genomic_align->dnafrag_end;
# #     my $starting_gap = $this_start_pos - $start_pos;
# #     my $ending_gap = $end_pos - $this_end_pos;
# # 
# #     my $ref_cigar_line = $this_genomic_align_block->reference_genomic_align->cigar_line;
# # 
# #     my $gap_coordinates = [];
# #     my $seq_pos = 0;
# #     my @cig = ($ref_cigar_line =~ /(\d*[GMD])/g);
# #     while (my $cigElem = shift(@cig)) {
# #       my $cigType = substr( $cigElem, -1, 1 );
# #       my $cigCount = substr( $cigElem, 0 ,-1 );
# #       $cigCount = 1 unless $cigCount;
# # 
# #       if ($cigType eq "M") {
# #         $seq_pos += $cigCount;
# #       } elsif ($cigType eq "G" || $cigType eq "D") {
# #         my $this_gap_insertions;
# #         $this_gap_insertions->{GAB_ID} = $this_genomic_align_block->dbID;
# #         $this_gap_insertions->{COORDINATES} = [($starting_gap + $seq_pos), $cigCount];
# #         push(@$all_gap_insertions, $this_gap_insertions);
# #       }
# #     }
# #   }
# # 
# #   return $all_gap_insertions;
# # }
# # 
# # 
# # sub get_cigar_line_from_all_gap_insertions {
# #   my ($all_gap_insertions, $length) = @_;
# #   my $cigar_line = "";
# # 
# #   my $last_pos = 0;
# #   foreach my $this_gap_insertion (sort {$a->{COORDINATES}->[0] <=> $b->{COORDINATES}->[0]} @$all_gap_insertions) {
# #     my $start_pos = $this_gap_insertion->{COORDINATES}->[0];
# #     my $gap_length = $this_gap_insertion->{COORDINATES}->[1];
# #     $cigar_line .= ($start_pos - $last_pos)."M" if ($start_pos - $last_pos);
# #     $cigar_line .= $gap_length."D";
# #     $last_pos = $start_pos;
# #   }
# # 
# #   $cigar_line .= ($length - $last_pos)."M" if ($length - $last_pos);
# # 
# #   return $cigar_line;
# # }
