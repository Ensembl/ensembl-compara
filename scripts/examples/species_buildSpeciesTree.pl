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

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;


#
# This script creates a species tree for a given list of species using
# the NCBITaxon facilities of the Compara database
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $taxonDBA = $reg->get_adaptor("Multi", "compara", "NCBITaxon");

my @list_of_species = ("Homo sapiens","Mus musculus","Drosophila melanogaster","Caenorhabditis elegans");

my @taxon_ids = ();
foreach my $species_name (@list_of_species) {
  my $taxon = $taxonDBA->fetch_node_by_name($species_name);
  unless ($taxon) {
      warn "Cannot find '$species_name' in the NCBI taxonomy tables\n";
      next;
  }
  push @taxon_ids, $taxon->dbID;
}

my $root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree(
    -COMPARA_DBA    => $reg->get_DBAdaptor("Multi", "compara"),
    -SPECIES_SET    => undef,
    -NO_PREVIOUS    => 1,
    -RETURN_NCBI_TREE       => 1,
    -EXTRATAXON_SEQUENCED   => \@taxon_ids,
);

print "MRCA is ", $root->name, "\t", $root->taxon_id, "\n";
$root->print_tree(10);

