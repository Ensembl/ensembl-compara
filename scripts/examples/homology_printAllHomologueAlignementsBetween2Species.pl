#!/usr/bin/env perl

use strict;
use warnings;

use Bio::AlignIO;
use Bio::EnsEMBL::Registry;


#
# This script prints all the alignments of all the orthologue pairs
# between human and mouse
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


# get compara DBAdaptor
my $comparaDBA = $reg->get_DBAdaptor('compara', 'compara');

# get GenomeDB for human and mouse
my $humanGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("human");
my $human_gdb_id = $humanGDB->dbID;
my $mouseGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("mouse");
my $mouse_gdb_id = $mouseGDB->dbID;

my $mlss = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
    fetch_by_method_link_type_genome_db_ids('ENSEMBL_ORTHOLOGUES',[$human_gdb_id,$mouse_gdb_id]);

my $species_names = '';
foreach my $gdb (@{$mlss->species_set}) {
  $species_names .= $gdb->dbID.".".$gdb->name."  ";
}
printf("mlss(%d) %s : %s\n", $mlss->dbID, $mlss->method_link_type, $species_names);

my $homology_list = $comparaDBA->get_HomologyAdaptor->
    fetch_all_by_MethodLinkSpeciesSet($mlss);
printf("fetched %d homologies\n", scalar(@{$homology_list}));

foreach my $homology (@{$homology_list}) {
  my $sa = $homology->get_SimpleAlign("cdna");
  my $alignIO = Bio::AlignIO->newFh(-interleaved => 0, -fh => \*STDOUT, -format => "phylip", -idlength => 20);

  print $alignIO $sa;
}

