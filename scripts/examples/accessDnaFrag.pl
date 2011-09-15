#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script show how to fetch a Compara DNAFrag object, that can linked
# to a core Slice object (for example to find genes)
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);



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

