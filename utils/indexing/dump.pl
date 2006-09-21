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
