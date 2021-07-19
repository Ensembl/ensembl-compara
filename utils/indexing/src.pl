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

our $key = shift @ARGV || die;
our %source = (
   'h' => {qw(1 dbSNP 2 HGVbase 3 TSC),4,'Affy GeneChip 500K Mapping Array',5,'Affy GeneChip 100K Mapping Array' },
   'm' => {qw(1 dbSNP 2 Sanger)}
);
my $current_snp_id = 0;
open( my $fh1, $key.'sv.txt' );
open( my $fh2, $key.'svs.txt' );
open( my $fh3, '>'.$key.'snps.txt' );
my $shift = <$fh1>; # remove first line
   $shift = <$fh2>; 
my $F=1;
my $snp1 = n($fh1);
my $snp2 = n($fh2);
while( $snp1 && $snp2 ) {
  #warn "$snp1->[0]-$snp2->[0]";
  if( $snp2->[0] ) {
    if( $snp1->[0] ) {
      if($snp2->[0]<$snp1->[0]) {
        warn "ARGH!! snp2_ID < snp1_ID panic!! @{$snp2}";
        $snp2 = n($fh2)||[]; # get next synonym
      } elsif($snp2->[0]>$snp1->[0]) {
        print $fh3 "@$snp1\n";
        $snp1 = n($fh1); # get next snp...
      } else {
        push @{$snp1}, "$snp2->[1]:$snp2->[2]";
        $snp2 = n($fh2)||[]; # get next snp2
      }
    } else {
      warn "ARGH!!!! run out of snps";
    }
  } elsif( $snp1->[0] ) {
    print $fh3 "@$snp1\n";
    $snp1 = n($fh1);
  } else {
    $F = 0;
  }
}
if($snp1) {
  print $fh3 "@$snp1\n";
}

sub n {
  my $fh = shift;
  my $L = <$fh>;
  my $snp;
  if( $L ) { 
    chomp $L;
    my @L = split /\t/, $L;
    $snp = [ $L[0], $source{$key}{$L[1]}, $L[2]];
  }
  return $snp;
}
