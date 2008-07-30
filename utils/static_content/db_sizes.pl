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

print qq(
<table class="ss autocenter" style="width:50%;margin:0 25%" cellspacing="0">
 <tbody>
  <tr class="ss_header">
   <th class="bottom-border left-border">Species</th>
   <th class="bottom-border right-border">Data size (Gb)</th>
  </tr>);
my $F = 1;
foreach ( sort keys %X ) {
  printf qq(
  <tr style="vertical-align:top" class="bg$F">
   <td class="left-border">%-32.32s</td>
   <td class="right-border" style="text-align:right">%-11.11s</td>
  </tr>),
  $_, sprintf( "%0.1f",$X{$_}/1024/1024);
  $F = 3-$F;
}
printf qq(
  <tr>
   <th class="left-border">Sub-total</th>
   <th class="right-border" style="text-align:right">%-11.11s</th>
  </tr>
), sprintf( "%0.1f", $T2/1024/1024);
print qq(
  <tr>
   <th class="left-border">Multi-species</th>
   <th class="right-border">&nbsp;</th>
  </tr>);
foreach ( sort keys %Y ) {
  printf qq(
  <tr style="vertical-align:top" class="bg$F">
   <td class="left-border">%-32.32s</td>
   <td class="right-border" style="text-align:right">%-11.11s</td>
  </tr>),
  $_, sprintf( "%0.1f",$Y{$_}/1024/1024);
  $F = 3-$F;
}
printf qq(
  <tr>
   <th class="left-border">Total</th>
   <th class="right-border" style="text-align:right">%-11.11s</th>
  </tr>
 </tbody>
</table>
), sprintf( "%0.1f", $T/1024/1024);
