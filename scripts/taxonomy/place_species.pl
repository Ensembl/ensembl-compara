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

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;
use Data::Dumper;
use Getopt::Long;

my $master_url = 'mysql://ensro@compara1/sf5_ensembl_compara_master';
my $taxon_ids;
my $help;

GetOptions (
            "master_url=s"    => \$master_url,
            "taxon_ids=s"      => \$taxon_ids,
            "help"            => \$help,
           );


if ($help || ! defined $taxon_ids) {
    print <<'EOH';
place_species.pl -- Get the correct insertion point of new ensembl species in the species gene tree
./place_species.pl -master_url <master_url> -taxon_ids <taxon_id1,taxon_id2,taxon_id3>

Options
   --master_url         [Optional] url for the compara master database
   --taxon_ids                     taxon_ids to place in the tree separated by commas (no spaces)
   --help               [Optional] prints this message & exits

EOH
exit
}

my @taxon_ids = split /,/, $taxon_ids;

# ADAPTORS
my $master_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$master_url);

# SPECIES TREE
my $species_tree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree (-compara_dba => $master_dba, -extrataxon_sequenced=>[@taxon_ids]);

my $fmt = '%{-n}%{x-}:%{d}';
my $sp_tree_string = $species_tree->newick_format('ryo', $fmt);

my $NCBITaxonAdaptor = $master_dba->get_NCBITaxonAdaptor;
## The cache is clear due to a long-standing bug in the NCBITaxonAdaptor that keeps the tree structure that has been set by Utils::SpeciesTree->create_species_tree
$NCBITaxonAdaptor->_id_cache->clear_cache();

for my $taxon_id (@taxon_ids) {
    my $taxon_name = $NCBITaxonAdaptor->fetch_node_by_taxon_id($taxon_id)->scientific_name;
    $sp_tree_string =~ s/$taxon_name/======>$taxon_name<======/;
}

$species_tree->print_tree(0.2);
print $sp_tree_string, "\n";
