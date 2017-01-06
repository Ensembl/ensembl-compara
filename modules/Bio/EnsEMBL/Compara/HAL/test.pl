# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
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

die "Usage: $0 path/to/alignment.hal\n" unless $ARGV[0];

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
