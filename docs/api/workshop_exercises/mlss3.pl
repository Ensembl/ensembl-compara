use strict;
use warnings;

use Bio::EnsEMBL::Registry;


## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

# Get the Compara Adaptor for MethodLinkSpeciesSets
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor( "Multi", "compara", "MethodLinkSpeciesSet");

my $mlss = $mlssa->fetch_by_method_link_type_species_set_name("EPO", "mammals");

foreach my $genome_db (@{ $mlss->species_set_obj()->genome_dbs() }){
	print $genome_db->name(), "\n";
}
