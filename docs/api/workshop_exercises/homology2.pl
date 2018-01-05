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

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the compara mlss adaptor
my $mlss_adaptor = $reg->get_adaptor("Multi", "compara", "MethodLinkSpeciesSet");

## Get the compara homology adaptor
my $homology_adaptor = $reg->get_adaptor("Multi", "compara", "Homology");

## Species definition
my $species1 = 'human';
my $species2 = 'mouse';

## Get the MethodLinkSpeciesSet object describing the orthology between the two species
my $this_mlss = $mlss_adaptor->fetch_by_method_link_type_registry_aliases('ENSEMBL_ORTHOLOGUES', [$species1, $species2]);

## Get all the homologues
my $all_homologies = $homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($this_mlss);

## For each homology
my $count = 0;
foreach my $this_homology (@{$all_homologies}) {

  ## only keeps the one2one
  if ($this_homology->description() eq 'ortholog_one2one') {
    $count++;
  }
}

print "There are $count 1-to-1 orthologues between $species1 and $species2\n";

## Alternative (shorter) version
my $all_one2one = $homology_adaptor->fetch_all_by_MethodLinkSpeciesSet($this_mlss, -orthology_type => 'ortholog_one2one');

print "It should be the same number as: ", scalar(@{$all_one2one}), "\n";

