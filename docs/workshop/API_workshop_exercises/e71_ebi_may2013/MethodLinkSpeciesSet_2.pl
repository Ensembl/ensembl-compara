use strict;
use warnings;
use Data::Dumper;
use Bio::AlignIO;

use Bio::EnsEMBL::Registry;

# Auto-configure the registry
Bio::EnsEMBL::Registry->load_registry_from_db(
	-host=>"ensembldb.ensembl.org", -user=>"anonymous",
        -port=>'5306');

# Get the Compara Adaptor for MethodLinkSpeciesSets
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor(
    "Multi", "compara", "MethodLinkSpeciesSet");

my $mlss = $mlssa->fetch_by_method_link_type_species_set_name("EPO", "mammals");

print "# method_link_species_set_id : ", $mlss->dbID, "\n";
# $mlss->species_set_obj->genome_dbs() brings back a list ref of genome_db objects
foreach my $genome_db (@{ $mlss->species_set_obj->genome_dbs() }){
	print join("\t", $genome_db->name, $genome_db->dbID), "\n";
}
