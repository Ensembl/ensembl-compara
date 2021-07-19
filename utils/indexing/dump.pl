# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2021] EMBL-European Bioinformatics Institute
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

my $key = shift @ARGV;
my $species = $key eq 'h' ? 'Homo_sapiens' : 'Mus_musculus';
open I, $key.'snps.txt';
open O, ">input/$species/SNP.txt" || die;
while(<I>) {
  my($ID,$source,$name,@keywords) = split;
  my @K = map { (my $t=$_)=~ s/^\w+://;$t } @keywords;
  print O "$source SNP\t$name\t/$species/snpview?source=$source;snp=$name\t$name @K\tA $source SNP with ".(@keywords?@keywords." synonyms (@keywords)":'no synonyms')."\n";
}
close O;
close I;
