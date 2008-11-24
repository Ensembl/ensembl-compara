#!/usr/local/bin/perl
use strict;
use warnings;

use Bio::EnsEMBL::Registry;
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_db
  ( -host => 'ensembldb.ensembl.org',
    -user => 'anonymous');

## Get the MethodLinkSpeciesSet for constrained elements
## Note that the fetch_all_by_method_link_type returns an array of MLSS
## although we know there is only one MLSS for GERP_CONSTRAINED_ELEMENT
my $method_link_species_set_adaptor = $reg->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");
my $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_type("GERP_CONSTRAINED_ELEMENT");

## Get the GenomeDB object for Human
my $genome_db_adaptor = $reg->get_adaptor("Multi", "compara", "GenomeDB");
my $human_gdb = $genome_db_adaptor->fetch_by_name_assembly("Homo sapiens");

## Get the DnaFrag for chromosome human chr. 11
my $dnafrag_adaptor = $reg->get_adaptor("Multi", "compara", "DnaFrag");
my $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($human_gdb, "11");

## Get a Slice for human chr.11 200001-400000
my $slice = $dnafrag->slice->sub_Slice(200_001, 400_000);

## Get the constrained elements. Contrained elements are stored as alignments. In
## fact, they represent sub-regions of a longer, multiple alignment.
my $genomic_align_block_adaptor = $reg->get_adaptor("Multi", "compara", "GenomicAlignBlock");
my $gabs = $genomic_align_block_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($method_link_species_sets->[0], $slice);

## For each constrained element, print its location on the human (reference) genome.
## Human is the reference because we used it to query the database. If we were looking
## for constrained elements on a particular mouse region, mouse would be the reference.
foreach my $this_gab (@$gabs) {
  my $length = $this_gab->reference_slice_end - $this_gab->reference_slice_start;

  print "Constr.Elem. ", $this_gab->reference_slice_start, " - ", $this_gab->reference_slice_end, "  :  Score = ", $this_gab->score,
   " ; (l=", ($length),  ")\n";

}
