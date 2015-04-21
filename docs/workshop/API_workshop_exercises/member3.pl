# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

## Get the human gene adaptor
my $human_gene_adaptor = $reg->get_adaptor("Homo sapiens", "core", "Gene");

## Get the compara genemember adaptor
my $gene_member_adaptor = $reg->get_adaptor("Multi", "compara", "GeneMember");

## Get all existing gene object with the name FRAS1
my $these_genes = $human_gene_adaptor->fetch_all_by_external_name('FRAS1');

## For each of these genes
foreach my $this_gene (@{$these_genes}) {

  print $this_gene->source(), " ", $this_gene->stable_id(), ": ", $this_gene->description(), "\n";

  ## Get the compara member
  my $gene_member = $gene_member_adaptor->fetch_by_stable_id($this_gene->stable_id());

  ## Print some info for this member
  $gene_member->print_member();

  ## Get all the peptide member for this gene member
  my $peptide_members = $gene_member->get_all_SeqMembers();
  foreach my $this_peptide_member (@{$peptide_members}) {

    ## Print some info for this protein member
    $this_peptide_member->print_member();

    ## Print its sequence
    print $this_peptide_member->sequence(), "\n";

  }
}
