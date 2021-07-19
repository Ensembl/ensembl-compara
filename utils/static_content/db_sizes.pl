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

##
## As root du -sk *_{version}_* *_mart_{version} ensembl_go_{version} ensembl_compara_version_{version} > db_sizes.txt
## Then run utils/db_sizes < db_sizes.txt > db_sizes.inc
##

## Script to generate list of database sizes
## Please ensure that your output is called db_sizes.inc,
## not db_sizes.html

while(<STDIN>) {
  chomp;
  ($size,$_) = split;
    /health/             ? 1 
  : /_mart_/             ? ( $Y{'Mart'}           += $size, $T+=$size)
  : /ensembl_([a-z]+)_/  ? ( $Y{ucfirst($1)}+=       $size, $T+=$size)
  : /([a-z]+)_([a-z]+)_/ ? ( $X{ucfirst("$1 $2")} += $size, $T+=$size, $T2+=$size)
  :                        0
  ;
}

print qq{
<table class="ss autocenter" style="width:400px">
 <tbody>
  <tr class="ss_header">
   <th>Species</th>
   <th class="right">Data size (Gb)</th>
  </tr>};
my $F = 1;
foreach ( sort keys %X ) {
  printf qq(
  <tr class="bg$F">
   <td>%s</td>
   <td class="right">%s</td>
  </tr>),
  $_, sprintf( "%0.1f",$X{$_}/1024/1024);
  $F = 3-$F;
}
printf qq(
  <tr>
   <th>Sub-total</th>
   <th class="right">%s</th>
  </tr>
), sprintf( "%0.1f", $T2/1024/1024);
print qq(
  <tr>
   <th>Multi-species</th>
   <th></th>
  </tr>);
foreach ( sort keys %Y ) {
  printf qq(
  <tr class="bg$F">
   <td>%s</td>
   <td class="right">%s</td>
  </tr>),
  $_, sprintf( "%0.1f",$Y{$_}/1024/1024);
  $F = 3-$F;
}
printf qq(
  <tr>
   <th>Total</th>
   <th class="right">%s</th>
  </tr>
 </tbody>
</table>
), sprintf( "%0.1f", $T/1024/1024);
