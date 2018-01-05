#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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
my $comparaDBA = $reg->get_DBAdaptor('Multi', 'compara');

my $sp1 = "human";
my $sp2 = "mouse";
my $mlss = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_registry_aliases('ENSEMBL_ORTHOLOGUES', [$sp1, $sp2]);

my $species_names = '';
foreach my $gdb (@{$mlss->species_set->genome_dbs}) {
  $species_names .= $gdb->dbID.".".$gdb->name."  ";
}
printf("mlss(%d) %s : %s\n", $mlss->dbID, $mlss->method->type, $species_names);

my $homology_list = $comparaDBA->get_HomologyAdaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);
printf("fetched %d homologies\n", scalar(@{$homology_list}));

my $alignIO = Bio::AlignIO->newFh(-interleaved => 0, -fh => \*STDOUT, -format => "phylip", -idlength => 20);
foreach my $homology (@{$homology_list}) {
  my $sa = $homology->get_SimpleAlign(-seq_type => 'cds');
  print $alignIO $sa;
}

