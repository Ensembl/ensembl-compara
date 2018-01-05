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


#
# This script shows how to fetch and process the "super-trees" stored
# in the Compara database. The super-trees are trees of gene-trees.
#

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
    -host=>'ensembldb.ensembl.org',
    -user=>'anonymous', 
);

my %params = (
    -clusterset_id => 'default',
    -tree_type => 'supertree',
    -member_type => 'ncrna', ## or 'protein'
);

my $geneTree_Adaptor = $reg->get_adaptor("Multi", "compara", "GeneTree");
my $superTrees = $geneTree_Adaptor->fetch_all(%params);

for my $supertree (@$superTrees) {
    $supertree->expand_subtrees();
    print $supertree->get_value_for_tag('model_name'), "\t", scalar(@{$supertree->get_all_leaves}), "\n";
    # ...
}

