#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Time::HiRes qw { time };

my $reg_conf = shift;
die("must specify registry conf file on commandline\n") unless($reg_conf);
Bio::EnsEMBL::Registry->load_all($reg_conf);

# get compara DBAdaptor
my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('compara', 'compara');

my $mlss_list = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
        fetch_all_by_method_link_type('ENSEMBL_ORTHOLOGUES');

foreach my $mlss (@{$mlss_list}) {
  my $species_names = '';
  foreach my $gdb (@{$mlss->species_set}) {
    $species_names .= $gdb->dbID.".".$gdb->name."  ";
  }
  printf("mlss(%d) %s : %s\n", $mlss->dbID, $mlss->method_link_type, $species_names);
}

exit(0);

