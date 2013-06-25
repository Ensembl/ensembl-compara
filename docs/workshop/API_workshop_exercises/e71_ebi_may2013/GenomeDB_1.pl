use strict;
use warnings;
use Data::Dumper;
use Bio::AlignIO;

use Bio::EnsEMBL::Registry;

# Auto-configure the registry
Bio::EnsEMBL::Registry->load_registry_from_db(
	-host=>'ensembldb.ensembl.org', -user=>'anonymous', 
	-port=>'5306');


# Get the Compara GenomeDB Adaptor
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
	"Multi", "compara", "GenomeDB");

# Fetch a list ref of all the compara genome_dbs
my $list_ref_of_gdbs = $genome_db_adaptor->fetch_all();

foreach my $genome_db( @{ $list_ref_of_gdbs } ){
        my $taxon;
        eval { $taxon = $genome_db->taxon };
        if ($@) { 
                print "*** no taxon ID for ", $genome_db->name, " ***\n";
		next;
        } 
	print join("\t", $genome_db->name, $genome_db->assembly, $genome_db->genebuild), "\n";
}


