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

my $homology = $homologies->[0]; # take one of the homologies and look into it

foreach my $member (@{$homology->get_all_Members}) {

  # each AlignedMember contains both the information on the SeqMember and in
  # relation to the homology

  print (join " ", map { $member->$_ } qw(stable_id taxon_id))."\n";
  print (join " ", map { $member->$_ } qw(perc_id perc_pos perc_cov))."\n";

}
