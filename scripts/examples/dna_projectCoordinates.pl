#!/usr/local/bin/perl

####################################################################
# pairwise alignments using public Ensembl EPO alignments
# if used, please cite bioRxiv: https://doi.org/10.1101/2020.05.31.126169
# or final publication
####################################################################

use strict;
use warnings;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::AlignIO;
use Bio::EnsEMBL::Utils::Exception qw(throw);

# input and output
my $quer_name;
my $quer_bed;
my $ref_name;
my $out;

# global variables
my $genomicalign_adaptor;
my $genomedb_adaptor;
my $methodlink_adaptor;
my $slice_adaptor;


######################## usage and options ###############################
my $USAGE=("Given input bed files for a query species, will project the query species' genomic coordinates to a chosen reference genome.
    Valid species names are Ensembl database species names (eg. homo_sapiens).
    Takes into account only 1-to-1 pairwise alignments using the EPO alignment.

    Output file is a bed file of projected positions, and a column corresponding to original query positions:
    referenceSpecies_projected_chromosome\treferenceSpecies_projected_start\treferenceSpecies_projected_end\tquerySpecies_position

    where querSpecies_position is in format chromosome:start-end

    Run with following options:
    scripts/examples/dna_projectCoordinates.pl -quer_name query_species -quer_bed query.bed -ref_name reference_species -out out_file\n\n");

GetOptions('quer_name=s' => \$quer_name, 'quer_bed=s' => \$quer_bed,
    'ref_name=s' => \$ref_name, 'out=s' => \$out);

die $USAGE unless ($quer_name and $quer_bed and $ref_name and $out);



########################### subroutines ##########################
 # get the number of alignments in restricted genomic block
 # arg0: query species name
 # arg1: reference species name
 # arg2: query species slice
 # returns the genomic align blocks

sub blocks {
    my $query = $_[0];
    my $reference = $_[1];
    my $slice = $_[2];

    my $querydb = $genomedb_adaptor->fetch_by_name_assembly($query);
    my $referencedb = $genomedb_adaptor->fetch_by_name_assembly($reference);
    my $alignment = $methodlink_adaptor->fetch_by_method_link_type_species_set_name("EPO", "mammals");

    my $genomicalign_block = $genomicalign_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice( $alignment, $slice);
    return $genomicalign_block;
}

########################### main program ##########################


my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_registry_from_db(
    -host => 'ensembldb.ensembl.org',
    -user => 'anonymous'
);


# get the GenomicAlignBlock adaptor for Compara database
$genomicalign_adaptor = $registry->get_adaptor(
    "Multi", "Compara", "GenomicAlignBlock");

# get the GenomeDB adaptor of Compara database
$genomedb_adaptor = $registry->get_adaptor("Multi", "Compara", "GenomeDB");

# get the MethodLinkSpeciesSet adaptor of Compara
$methodlink_adaptor = $registry->get_adaptor("Multi", "Compara", "MethodLinkSpeciesSet");


print "Projecting query species: ", $quer_name, "\tto reference: ",
    $ref_name, "\n\tquery file: ", $quer_bed, "\n";

open (OUT, ">$out") or die "Cannot make outfile: $out\n";
print "\tmaking output: $out\n\n";

# make header for output file, including reference (projected) and query  positions
print OUT "#", $ref_name,"_projected_chr\t", $ref_name, "_projected_start\t",
$ref_name, "_projected_end\t", $quer_name, "_position\n";

# open in bed file
open (IN, $quer_bed) or die "cannot open $quer_bed\n";

 # get slice adaptor using query species
$slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($quer_name, "Core", "Slice");

while (<IN>) {
    chomp;
    # split bed file
    my @col = split(/\t/,$_);

    # make query slice using genomic coordinates
    my $query_slice = $slice_adaptor->fetch_by_region("toplevel", $col[0], $col[1], $col[2]);
    throw("No Slice can be created with coordinates $col[0]:$col[1]-$col[2]") if (!$query_slice);

    # pass to subroutine to get all possible alignment blocks
    my $all_blocks = blocks($quer_name,$ref_name,$query_slice);

    # check that there is only one alignment (block)
    if ( scalar @$all_blocks == 1 ) {
        # go through the block
        foreach my $block (@$all_blocks) {
            next if (!defined $block);

            # restrict blok to position of slice
            my $restricted = $block->restrict_between_reference_positions(
                $query_slice->start(), $query_slice->end(), undef, 1);
            next if (!defined $restricted);

            # get all the alignments in the block
            my $align_list = $restricted->genomic_align_array();

            # go thorugh the alignments
            foreach my $align (@$align_list) {
                next if (!$align);
                #get the alignment from reference species
                if ($align->genome_db()->name() eq $ref_name) {

                    # print out reference (projected) and query coordinates
                    print OUT $align->dnafrag->name(), "\t", $align->dnafrag_start(),
                    "\t", $align->dnafrag_end(), "\t",
                    $query_slice->seq_region_name(), ":",
                    $query_slice->start(), "-", $query_slice->end(), "\n";
                }
            }
        }
    }
}

close(OUT);
close(IN);

