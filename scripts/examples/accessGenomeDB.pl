#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

# my $reg_conf = shift;
# die("must specify registry conf file on commandline\n") unless($reg_conf);
# Bio::EnsEMBL::Registry->load_all($reg_conf);

Bio::EnsEMBL::Registry->load_registry_from_db
  ( -host => 'ensembldb.ensembl.org',
    -user => 'anonymous',
    -verbose => "1" );

# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry->get_DBAdaptor('compara', 'compara');

# get GenomeDB for human
my $humanGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("human");

# get DBAdaptor for Human ensembl core database
my $human_core_DBA = $humanGDB->db_adaptor;

# print some info
printf("COMPARA %s : %s : %s\n   %s\n", $humanGDB->name, $humanGDB->assembly, $humanGDB->genebuild, 
    join("_", reverse($humanGDB->taxon->classification)));

my $species_name = $human_core_DBA->get_MetaContainer->get_Species->binomial;
my $species_assembly = $human_core_DBA->get_CoordSystemAdaptor->fetch_all->[0]->version;
my $species_genebuild = $human_core_DBA->get_MetaContainer->get_genebuild;
printf("CORE    %s : %s : %s\n", $species_name, $species_assembly, $species_genebuild);

exit(0);

