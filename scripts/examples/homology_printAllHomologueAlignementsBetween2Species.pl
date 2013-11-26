#!/usr/bin/env perl
# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

# get GenomeDB for human and mouse
my $humanGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("human");
my $human_gdb_id = $humanGDB->dbID;
my $mouseGDB = $comparaDBA->get_GenomeDBAdaptor->fetch_by_registry_name("mouse");
my $mouse_gdb_id = $mouseGDB->dbID;

my $mlss = $comparaDBA->get_MethodLinkSpeciesSetAdaptor->
    fetch_by_method_link_type_genome_db_ids('ENSEMBL_ORTHOLOGUES',[$human_gdb_id,$mouse_gdb_id]);

my $species_names = '';
foreach my $gdb (@{$mlss->species_set_obj->genome_dbs}) {
  $species_names .= $gdb->dbID.".".$gdb->name."  ";
}
printf("mlss(%d) %s : %s\n", $mlss->dbID, $mlss->method->type, $species_names);

my $homology_list = $comparaDBA->get_HomologyAdaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);
printf("fetched %d homologies\n", scalar(@{$homology_list}));

foreach my $homology (@{$homology_list}) {
  my $sa = $homology->get_SimpleAlign(-seq_type => 'cds');
  my $alignIO = Bio::AlignIO->newFh(-interleaved => 0, -fh => \*STDOUT, -format => "phylip", -idlength => 20);

  print $alignIO $sa;
}

