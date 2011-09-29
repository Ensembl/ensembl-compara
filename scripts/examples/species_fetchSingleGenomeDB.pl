#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script queries the Compara and the Core databases to fetch 
# information about the human genome
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $genomedb_adaptor = $reg->get_adaptor('Multi', 'compara', 'GenomeDB');

# get GenomeDB for human
my $humanGDB = $genomedb_adaptor->fetch_by_registry_name("human");

# get DBAdaptor for Human ensembl core database
my $human_core_DBA = $humanGDB->db_adaptor;

# print some info
printf("COMPARA %s : %s : %s\n   %s\n", $humanGDB->name, $humanGDB->assembly, $humanGDB->genebuild, 
    join("_", reverse($humanGDB->taxon->classification)));

my $species_name = $human_core_DBA->get_MetaContainer->get_Species->binomial;
my $species_assembly = $human_core_DBA->get_CoordSystemAdaptor->fetch_all->[0]->version;
my $species_genebuild = $human_core_DBA->get_MetaContainer->get_genebuild;
printf("CORE    %s : %s : %s\n", $species_name, $species_assembly, $species_genebuild);

