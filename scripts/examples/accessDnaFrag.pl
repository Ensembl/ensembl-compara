#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $reg_conf = shift;
die("must specify registry conf file on commandline\n") unless($reg_conf);
Bio::EnsEMBL::Registry->load_all($reg_conf);

# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry->get_DBAdaptor('compara', 'compara');

# get GenomeDB for human
my $humanGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("human");

# get dnafrag for human chr 18
my $dnafrag_list = $comparaDBA->get_DnaFragAdaptor->
     fetch_all_by_GenomeDB_region($humanGDB, 'chromosome', "18");
my $dnafrag = shift @{$dnafrag_list};

# get its core Slice and subslice it
my $slice = $dnafrag->slice;
$slice = $slice->sub_Slice(75000000,76000000,1);

# the the genes on the subslice and print
my $genes = $slice->get_all_Genes;
foreach my $gene (@{$genes}) {
  printf("%s\n", $gene->stable_id);
}

exit(0);

