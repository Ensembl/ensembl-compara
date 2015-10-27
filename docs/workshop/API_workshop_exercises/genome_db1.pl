use strict;
use warnings;

use Bio::EnsEMBL::Registry;


## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');


# Get the Compara GenomeDB Adaptor
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor( "Multi", "compara", "GenomeDB");

# Fetch a list ref of all the compara genome_dbs
my $list_ref_of_gdbs = $genome_db_adaptor->fetch_all();

foreach my $genome_db( @{ $list_ref_of_gdbs } ){
    print join("\t", $genome_db->name(), $genome_db->assembly(), $genome_db->genebuild()), "\n";
}

