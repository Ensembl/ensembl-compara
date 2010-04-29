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
my $version = 58;

$reg->load_registry_from_db(
      -host => "ensembldb.ensembl.org",
      -user => "anonymous",
      -db_version => $version);

#get method_link_species_set adaptor
my $mlss_adaptor = $reg->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");

#get method_link_species_set object for gerp conservation scores for mammals
my $mlss = $mlss_adaptor->fetch_by_method_link_type_species_set_name("GERP_CONSERVATION_SCORE", "mammals");

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
