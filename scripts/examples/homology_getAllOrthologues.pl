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


#
# This script retrieves all the homologs and paralogs between two species
#

use Bio::EnsEMBL::Registry;

my $reg = 'Bio::EnsEMBL::Registry';

$reg->load_registry_from_db(
  -host=>'ensembldb.ensembl.org',
  -user=>'anonymous', 
);


my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

my $comparaDBA = Bio::EnsEMBL::Registry-> get_DBAdaptor('Multi', 'compara');
my $homology_adaptor = $comparaDBA->get_HomologyAdaptor;
my $mlss_adaptor = $comparaDBA->get_MethodLinkSpeciesSetAdaptor;

my $sp1 = "human";
my $sp2 = "mouse";

my $mlss_orth = $mlss_adaptor->fetch_by_method_link_type_registry_aliases('ENSEMBL_ORTHOLOGUES', [$sp1, $sp2]);
my @orthologies = @{$homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_orth)};

print scalar(@orthologies), " orthologies between $sp1 and $sp2\n";

