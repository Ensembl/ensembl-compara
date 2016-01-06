#!/usr/bin/env perl
# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;

#
# Script to print the species-tree used by a given method
#

my $url = 'mysql://anonymous@ensembldb.ensembl.org/ensembl_compara_'.software_version();
my $mlss_id;
my $method = 'PROTEIN_TREES';
my $ss_name;

GetOptions(
       'url=s'          => \$url,
       'mlss_id=s'      => \$mlss_id,
       'method=s'       => \$method,
       'ss_name=s'      => \$ss_name,
);


my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url => $url) or die "Must define a url";

unless ($mlss_id) {
    if ($ss_name) {
        my $mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_species_set_name($method, $ss_name);
        die "No MLSSs found for the method '$method' and the species-set '$ss_name'\n" unless $mlss;
        $mlss_id = $mlss->dbID;
    } else {
        my $all_mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type($method);
        die "No MLSSs found for the method '$method'\n" unless scalar($all_mlss);
        $mlss_id = $all_mlss->[0]->dbID;
    }
}

my $species_tree = $compara_dba->get_SpeciesTreeAdaptor()->fetch_by_method_link_species_set_id_label($mlss_id, 'default');

print $species_tree->root->newick_format( 'ryo', '%{n}' ), "\n";



