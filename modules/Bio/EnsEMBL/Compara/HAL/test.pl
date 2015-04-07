use strict;
use warnings;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::HAL::HALAdaptor;
use Data::Dumper;

# take care of Ensembl DB boilerplate
my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_registry_from_db(
    -host => 'ensembldb.ensembl.org', # alternatively 'useastdb.ensembl.org'
    -user => 'anonymous'
    );

my $halAdaptor = Bio::EnsEMBL::Compara::HAL::HALAdaptor->new($ARGV[0]);
print "Hal genomes:\n";
foreach my $genome ($halAdaptor->genomes()) {
    print ($genome, Dumper($halAdaptor->genome_metadata($genome)), "\n");
}

print "Ensembl genomes:\n";
foreach my $ensembl_genome ($halAdaptor->ensembl_genomes()) {
    print ($ensembl_genome, "\n");
}

my $gaba = $halAdaptor->get_adaptor("GenomicAlignBlock");
my $mlssa = $halAdaptor->get_adaptor("MethodLinkSpeciesSet");
my $mlss = $mlssa->fetch_all_by_method_link_type('HAL');

my $sliceAdaptor = $registry->get_adaptor('Mouse', 'Core', 'Slice');
my $slice = $sliceAdaptor->fetch_by_region('chromosome', 'X', 5000000, 5100000);
foreach my $gab ($gaba->fetch_all_by_MethodLinkSpeciesSet_Slice($mlss, $slice)) {
    $gab->_print;
}
