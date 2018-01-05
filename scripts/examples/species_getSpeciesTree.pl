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

use Getopt::Long;

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;

#
# Script to print the species-tree used by a given method
#

my $url = 'mysql://anonymous@ensembldb.ensembl.org/ensembl_compara_'.software_version();
my $mlss_id;
my $method = 'PROTEIN_TREES';
my $ss_name;
my $label = 'default';
my $with_distances;
my $ascii_scale;

GetOptions(
       'url=s'          => \$url,
       'mlss_id=s'      => \$mlss_id,
       'method=s'       => \$method,
       'ss_name=s'      => \$ss_name,
       'label=s'        => \$label,
       'with_distances' => \$with_distances,
       'ascii_scale=f'  => \$ascii_scale,
);


my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url => $url) or die "Must define a url";

my $mlss;
if ($mlss_id) {
    $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
} elsif ($method) {
    if ($ss_name) {
        $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_species_set_name($method, $ss_name);
    } else {
        $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type($method)->[0];
    }
}
die "Could not fetch a MLSS with these parameters. Check your mlss_id, method and/or ss_name arguments\n" unless $mlss;

my $species_tree = $mlss->species_tree($label);

if ($ascii_scale) {
    $species_tree->root->print_tree($ascii_scale);
} else {
    print $species_tree->root->newick_format( 'ryo', $with_distances ? '%{n}:%{d}' : '%{n}' ), "\n";
}

