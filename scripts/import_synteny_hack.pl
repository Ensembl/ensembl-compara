my @chr = (1..22,'X','Y');
   my $c=0;
foreach my $human_chr (@chr) {
   open I,"$human_chr.final.gff";
   while(<I>) {
	$human_chr = 23 if $human_chr eq 'X';
	$human_chr = 24 if $human_chr eq 'Y';
	next unless /.*?(\d+)\s+(\d+)\s+\d+\s+(\S+)\s+\.\s+(\S+)\s+(\d+)\s(\d+)/;
	my($human_s,$human_e,$relori,$mouse_chr, $mouse_s, $mouse_e) = ($1,$2,$3,$4,$5,$6);
	if($mouse_chr eq 'X') { $mouse_chr = 50; }
	elsif($mouse_chr eq 'Y') { $mouse_chr = 51; }
	else { $mouse_chr = $mouse_chr+30; }
	$c++;
	print "insert into synteny_region values($c,$relori);\n";
	print "insert into dnafrag_region values($c,$human_chr,$human_s,$human_e);\n";
	print "insert into dnafrag_region values($c,$mouse_chr,$mouse_s,$mouse_e);\n";
   }
   close I;
}
