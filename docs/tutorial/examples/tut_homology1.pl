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

# first you have to get a GeneMember object. In case of homology is a gene, in 
# case of family it can be a gene or a protein

my $gene_member_adaptor = Bio::EnsEMBL::Registry->get_adaptor('Multi', 'compara', 'GeneMember');
my $gene_member = $gene_member_adaptor->fetch_by_source_stable_id('ENSEMBLGENE','ENSG00000004059');

# then you get the homologies where the member is involved

my $homology_adaptor = Bio::EnsEMBL::Registry->get_adaptor('Multi', 'compara', 'Homology');
my $homologies = $homology_adaptor->fetch_all_by_Member($gene_member);

# That will return a reference to an array with all homologies (orthologues in
# other species and paralogues in the same one)
# Then for each homology, you can get all the Members implicated

foreach my $homology (@{$homologies}) {
  # You will find different kind of description
  # see ensembl-compara/docs/docs/schema_doc.html for more details

  print $homology->description," ", $homology->taxonomy_level,"\n";

  # And if they are defined dN and dS related values

  print " dn ", $homology->dn,"\n";
  print " ds ", $homology->ds,"\n";
  print " dnds_ratio ", $homology->dnds_ratio,"\n";
}
