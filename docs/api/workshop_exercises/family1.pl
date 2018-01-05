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
use Bio::AlignIO;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');


## Get the compara family adaptor
my $family_adaptor = $reg->get_adaptor("Multi", "compara", "Family");

## Get all the families
my $this_family = $family_adaptor->fetch_by_stable_id('PTHR10740_SF4');

## Description of the family
print $this_family->description(), " (description score = ", $this_family->description_score(), ")\n";

## BioPerl alignment
my $simple_align = $this_family->get_SimpleAlign(-append_taxon_id => 1);
my $alignIO = Bio::AlignIO->newFh(-format => "clustalw");
print $alignIO $simple_align;

