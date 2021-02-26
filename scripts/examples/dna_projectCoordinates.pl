#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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

####################################################################
# pairwise projections using an EPO alignment
# Used for https://doi.org/10.1101/2020.05.31.126169
####################################################################

use strict;
use warnings;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::AlignIO;
use Bio::EnsEMBL::Utils::Exception qw(throw);

# input and output
my $query_name;
my $query_bed;
my $target_name;
my $aln_name = 'mammals';
my $out;

# global variables
my $genomicalign_adaptor;
my $genomedb_adaptor;
my $methodlink_adaptor;
my $slice_adaptor;


######################## usage and options ###############################
my $USAGE=("Given input bed files for a query species, will project the query species' genomic coordinates to a chosen target genome.
    Valid species names are Ensembl database species names (eg. homo_sapiens).
    Takes into account only 1-to-1 pairwise alignments using the EPO alignment.

    Output file is a bed file of projected positions, and a column corresponding to original query positions:
    targetSpecies_projected_chromosome\treferenceSpecies_projected_start\treferenceSpecies_projected_end\tquerySpecies_position

    where querSpecies_position is in format chromosome:start-end

    Run with following options:
    scripts/examples/dna_projectCoordinates.pl -query_name query_species -query_bed query.bed -target_name target_species -out out_file\n\n");

GetOptions(
    'query_name=s'  => \$query_name,
    'query_bed=s'   => \$query_bed,
    'target_name=s' => \$target_name,
    'aln_name=s'    => \$aln_name,
    'out=s'         => \$out,
);

die $USAGE unless ($query_name and $query_bed and $target_name and $out);



########################### subroutines ##########################
 # get the number of alignments in restricted genomic block
 # arg0: query species name
 # arg1: target species name
 # arg2: query species slice
 # returns the genomic align blocks

sub blocks {
    my $query = $_[0];
    my $target = $_[1];
    my $slice = $_[2];

    my $querydb = $genomedb_adaptor->fetch_by_name_assembly($query);
    my $targetdb = $genomedb_adaptor->fetch_by_name_assembly($target);
    my $alignment = $methodlink_adaptor->fetch_by_method_link_type_species_set_name("EPO", $aln_name);

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


print "Projecting query species: ", $query_name, "\tto target: ",
    $target_name, "\n\tquery file: ", $query_bed, "\n";

open (my $out_fh, '>', $out) or die "Cannot make outfile: $out\n";
print "\tmaking output: $out\n\n";

# make header for output file, including target (projected) and query  positions
print $out_fh "#", $target_name,"_projected_chr\t", $target_name, "_projected_start\t",
$target_name, "_projected_end\t", $query_name, "_position\n";

# open in bed file
open (my $in_fh, '<', $query_bed) or die "cannot open $query_bed\n";

 # get slice adaptor using query species
$slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($query_name, "Core", "Slice");

while (<$in_fh>) {
    chomp;
    # split bed file
    my @col = split(/\t/,$_);

    # make query slice using genomic coordinates
    my $query_slice = $slice_adaptor->fetch_by_region("toplevel", $col[0], $col[1], $col[2]);
    throw("No Slice can be created with coordinates $col[0]:$col[1]-$col[2]") if (!$query_slice);

    # pass to subroutine to get all possible alignment blocks
    my $all_blocks = blocks($query_name,$target_name,$query_slice);

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
                #get the alignment from target species
                if ($align->genome_db()->name() eq $target_name) {

                    # print out target (projected) and query coordinates
                    print $out_fh $align->dnafrag->name(), "\t", $align->dnafrag_start(),
                    "\t", $align->dnafrag_end(), "\t",
                    $query_slice->seq_region_name(), ":",
                    $query_slice->start(), "-", $query_slice->end(), "\n";
                }
            }
        }
    }
}

close($out_fh);
close($in_fh);

