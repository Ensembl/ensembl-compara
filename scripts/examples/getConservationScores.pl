#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);

#
# Simple example to show how to get conservation scores for a slice.
# Works for ensembl release 51
#

my $reg = "Bio::EnsEMBL::Registry";
my $species = "Homo sapiens";
my $seq_region = "17";
my $seq_region_start = 32020001;
my $seq_region_end =   32020500;
my $version = 51;

$reg->load_registry_from_db(
      -host => "ensembldb.ensembl.org",
      -user => "anonymous",
      -db_version => $version);

#get method_link_species_set adaptor
my $mlss_adaptor = $reg->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");

my $mlss; 

#get the method_link_species_set object for GERP_CONSERVATION_SCORE for 21 species
#$mlss = $mlss_adaptor->fetch_by_method_link_type_registry_aliases("GERP_CONSERVATION_SCORE", ["human", "chimp", "rhesus", "Pongo pygmaeus", "cow", "dog", "mouse", "rat", "horse", "Echinops telfairi", "Oryctolagus cuniculus", "Dasypus novemcinctus", "Tupaia belangeri", "Erinaceus europaeus", "Otolemur garnettii", "Spermophilus tridecemlineatus", "Myotis lucifugus", "Sorex araneus", "Microcebus murinus", "Felis catus", "Ochotona princeps"]);

#A quicker way is to define the number of species in the alignment and
#get all the method_link_species_sets with type "GERP_CONSERVATION_SCORE" and
#select the one with the required number of species. This of course assumes 
#that there are not two different method_link_species_sets with the same
#number of species in which case you would have to use the method above and
#declare each species individually.

my $num_species = 21;

my $all_mlss =  $mlss_adaptor->fetch_all_by_method_link_type("GERP_CONSERVATION_SCORE");
foreach my $this_mlss (@$all_mlss) {
    #print "number of species " . @{$this_mlss->species_set} . "\n";
    if (@{$this_mlss->species_set} == $num_species) {
	$mlss = $this_mlss;
	last;
    }
}

throw("Unable to find method_link_species_set") if (!defined($mlss));

#get slice adaptor for $species
my $slice_adaptor = $reg->get_adaptor($species, 'core', 'Slice');
throw("Registry configuration file has no data for connecting to <$species>") if (!$slice_adaptor);

#create slice 
my $slice = $slice_adaptor->fetch_by_region('toplevel', $seq_region, $seq_region_start, $seq_region_end);
throw("No Slice can be created with coordinates $seq_region:$seq_region_start-$seq_region_end") if (!$slice);

#get conservation score adaptor
my $cs_adaptor = $reg->get_adaptor("Multi", 'compara', 'ConservationScore');			
#To get one score per base in the slice, must set display_size to the size of
#the slice.
my $display_size = $slice->end - $slice->start + 1; 
my $scores = $cs_adaptor->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice, $display_size);

print "number of scores " . @$scores . "\n";

#print out the position, observed, expected and difference scores.
foreach my $score (@$scores) {
    if (defined $score->diff_score) {
	printf("position %d observed %.4f expected %.4f difference %.4f\n",  $score->position, $score->observed_score, $score->expected_score, $score->diff_score);
    }
}
