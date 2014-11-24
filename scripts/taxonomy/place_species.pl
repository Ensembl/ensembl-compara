#!/usr/bin/env perl
# Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

for my $taxon_id (@taxon_ids) {
    my $nodes = $species_tree->find_nodes_by_field_value('taxon_id', $taxon_id);
    die "There should be a node with taxon_id=$taxon_id in the tree !\n" if scalar(@$nodes) == 0;
    die "There should be a single node with taxon_id=$taxon_id in the tree !\n" if scalar(@$nodes) >= 2;
    my $new_leaf = $nodes->[0];
    my $new_internal_node = $new_leaf->parent;
    my $timetree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->get_timetree_estimate($new_internal_node);
    $new_leaf->node_name(sprintf('======>New species: taxon_id=%d name="%s"<======', $taxon_id, $new_leaf->node_name));
    $new_internal_node->node_name(sprintf('======>New ancestor taxon_id=%d name="%s" timetree="%s mya")<======', $new_internal_node->taxon_id, $new_internal_node->node_name, $timetree));
}

$species_tree->print_tree(0.2);

my $fmt = '%{-n}%{x-}:%{d}';
my $sp_tree_string = $species_tree->newick_format('ryo', $fmt);
print $sp_tree_string, "\n";
