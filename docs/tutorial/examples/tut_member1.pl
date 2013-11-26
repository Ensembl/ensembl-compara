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

# get the MemberAdaptor
my $genemember_adaptor = Bio::EnsEMBL::Registry->get_adaptor(
    'Multi','compara','GeneMember');

# fetch a Member
my $member = $genemember_adaptor->fetch_by_source_stable_id(
    'ENSEMBLGENE','ENSG00000004059');

# print out some information about the Member
print $member->chr_name, " ( ", $member->dnafrag_start, " - ", $member->dnafrag_end,
    " ): ", $member->description, "\n";
