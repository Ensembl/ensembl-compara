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
use warnings;

use Bio::AlignIO;

use Bio::EnsEMBL::Registry;

## Load the registry automatically
my $reg = "Bio::EnsEMBL::Registry";
$reg->load_registry_from_url('mysql://anonymous@ensembldb.ensembl.org');

## Get the compara member adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");

## Get the compara homology adaptor
my $homology_adaptor = $reg->get_adaptor("Multi", "compara", "Homology");

## The BioPerl alignment formatter
my $alignIO = Bio::AlignIO->newFh(-format => "clustalw");

foreach my $mouse_stable_id (qw(ENSMUSG00000004843 ENSMUSG00000025746)) {

  ## Get the compara member
  my $gene_member = $gene_member_adaptor->fetch_by_source_stable_id("ENSEMBLGENE", $mouse_stable_id);

  ## Get all the orthologues in human
  my $all_homologies = $homology_adaptor->fetch_all_by_Member_paired_species($gene_member, 'homo_sapiens', ['ENSEMBL_ORTHOLOGUES']);

  ## For each homology
  foreach my $this_homology (@{$all_homologies}) {

    $this_homology->print_homology();
    print "The non-synonymous substitution rate is: ", $this_homology->dn(), "\n";

    ## Get and print the alignment
    my $simple_align = $this_homology->get_SimpleAlign();
    print $alignIO $simple_align;
  }
  print "\n";
}

