#!/usr/bin/env perl

use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script queries the Compara database to fetch all the MethodLinkSpeciesSet
# objects used by orthologies
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $mlss_adaptor = $reg->get_adaptor('Multi', 'compara', 'MethodLinkSpeciesSet');
my $mlss_list = $mlss_adaptor->fetch_all_by_method_link_type('ENSEMBL_ORTHOLOGUES');

foreach my $mlss (@{$mlss_list}) {
  my $species_names = '';
  foreach my $gdb (@{$mlss->species_set}) {
    $species_names .= $gdb->dbID.".".$gdb->name."  ";
  }
  printf("mlss(%d) %s : %s\n", $mlss->dbID, $mlss->method_link_type, $species_names);
}

