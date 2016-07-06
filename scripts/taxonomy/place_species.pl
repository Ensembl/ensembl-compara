#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016] EMBL-European Bioinformatics Institute
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

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;
use Data::Dumper;
use Getopt::Long;

my $master_url = 'mysql://ensro@compara1/mm14_ensembl_compara_master';
my $taxon_ids;
my $help;
my $collection;

GetOptions (
            "master_url=s"    => \$master_url,
            "taxon_ids=s"      => \$taxon_ids,
            "collection=s"    => \$collection,
            "help"            => \$help,
           );


if ($help || ! defined $taxon_ids || !$collection) {
    print <<'EOH';
place_species.pl -- Get the correct insertion point of new ensembl species in the species gene tree
./place_species.pl -master_url <master_url> -collection <collection_name> -taxon_ids <taxon_id1,taxon_id2,taxon_id3>

Options
   --master_url         [Optional] url for the compara master database
   --collection         Name of the collection (species-set) in which to add the new taxa
   --taxon_ids                     taxon_ids to place in the tree separated by commas (no spaces)
   --help               [Optional] prints this message & exits

EOH
exit
}

my @taxon_ids = split /,/, $taxon_ids;

# ADAPTORS
my $master_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$master_url);

my $collection_ss = $master_dba->get_SpeciesSetAdaptor->fetch_collection_by_name($collection);

# SPECIES TREE
my $species_tree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree (-compara_dba => $master_dba, -species_set => $collection_ss, -extrataxon_sequenced=>[@taxon_ids]);

for my $taxon_id (@taxon_ids) {
    my $nodes = $species_tree->find_nodes_by_field_value('taxon_id', $taxon_id);
    die "There should be a node with taxon_id=$taxon_id in the tree !\n" if scalar(@$nodes) == 0;
    die "There should be a single node with taxon_id=$taxon_id in the tree !\n" if scalar(@$nodes) >= 2;
    my $new_leaf = $nodes->[0];
    my $new_internal_node = $new_leaf->parent;
    my $internal_taxon = $master_dba->get_NCBITaxonAdaptor->fetch_node_by_taxon_id($new_internal_node->taxon_id);
    my @common_names = ();
    push @common_names, @{$internal_taxon->get_all_values_for_tag('common name')};
    push @common_names, @{$internal_taxon->get_all_values_for_tag('genbank common name')};
    my $cn_string = scalar(@common_names) ? join('/', map {qq{"$_"}} @common_names) : '?';
    my $timetree = Bio::EnsEMBL::Compara::Utils::SpeciesTree->get_timetree_estimate($new_internal_node);
    $new_leaf->node_name(sprintf('======>New species: taxon_id=%d name="%s"<======', $taxon_id, $new_leaf->node_name));
    $new_internal_node->node_name(sprintf('======>New ancestor taxon_id=%d name="%s" common_names=%s timetree="%s mya")<======', $new_internal_node->taxon_id, $new_internal_node->node_name, $cn_string, $timetree || '?'));
}

$species_tree->print_tree(0.2);

my $fmt = '%{n}';
my $sp_tree_string = $species_tree->newick_format('ryo', $fmt);
print $sp_tree_string, "\n";
