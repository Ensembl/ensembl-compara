use strict;
use warnings;

use Bio::EnsEMBL::Registry;


## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

# Get the Compara Adaptor for MethodLinkSpeciesSets
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor( "Multi", "compara", "MethodLinkSpeciesSet");

# fetch_all() method returns a array ref.
my $all_mlss = $mlssa->fetch_all();

my (%CT, $total_count);

foreach my $method_link_species_set (@{ $all_mlss }){
	$CT{ $method_link_species_set->method()->type() }++;
	$total_count++;
}

print "number of analyses: ", $total_count, "\n";
foreach my $method_link_type (keys %CT){
	print $method_link_type, ": ", $CT{$method_link_type}, "\n";
}
