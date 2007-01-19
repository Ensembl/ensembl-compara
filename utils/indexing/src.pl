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
