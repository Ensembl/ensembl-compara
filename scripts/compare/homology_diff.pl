#!/usr/bin/perl
=head1
  this script takes homology dumps generated with this SQL statement from two different
  compara databases and compares them for differences.  

  TODO: make this more general, maybe using DBI to connect to the 2 compara DBs
  and do the dump here.

$sql = "SELECT m1.stable_id, m2.stable_id, h.description" .
       " FROM homology h, homology_member hm1, homology_member hm2, member m1, member m2 ".
       " WHERE h.homology_id=hm1.homology_id AND hm1.member_id=m1.member_id AND m1.genome_db_id=2 ".
       " AND h.homology_id=hm2.homology_id AND hm2.member_id=m2.member_id AND m2.genome_db_id=3 ".
       " ORDER BY  m1.stable_id, m2.stable_id";
=cut


$compara20file = shift;
$compara21file = shift;

open RH20, $compara20file;
open RH21, $compara21file;
$compara20 = {};
$compara20_dup = {};

$sameBRH=0;
$sameRHS=0;
$BRH2RHS=0;
$RHS2BRH=0;
$countAdds=0;
$count20=0;
$count21=0;
$BRHCount=0;
$RHSCount=0;
$newBRH=0;
$newRHS=0;


foreach $line (<RH20>) {
  ($mouseGene20, $ratGene20, $type20) = split(/\s/, $line);
	$key = $mouseGene20 ."_". $ratGene20;
	#print("storing compara20 key='$key' value='$type20'\n");
  $count20++;
  if($compara20->{$key}) {
	  print("compara20 duplicate\n$line\nalready as ".$compara20->{$key}."\n");
	}
	$BRHCount++ if($type20 eq 'BRH');
	$RHSCount++ if($type20 eq 'RHS');

  $compara20->{$key} = $type20;
  $compara20_dup->{$key} = $type20;
}


foreach $line (<RH21>) {
  ($mouseGene21, $ratGene21, $type21) = split(/\s/, $line);
	$key = $mouseGene21 ."_". $ratGene21;
  $type20 = $compara20->{$key};
	#print("check compara21 key='$key' '$type21' vs '$type20'\n");
  $count21++;
	#$BRHCount++ if($type21 eq 'BRH');
	#$RHSCount++ if($type21 eq 'RHS');
	if($type20) {
  	#print("check compara21 key='$key' '$type21' vs '$type20'\n");
	  $sameBRH++ if(($type20 eq 'BRH') and ($type21 eq 'BRH'));
		$sameRHS++ if(($type20 eq 'RHS') and ($type21 eq 'RHS'));
		$BRH2RHS++ if(($type20 eq 'BRH') and ($type21 eq 'RHS'));
		$RHS2BRH++ if(($type20 eq 'RHS') and ($type21 eq 'BRH'));

    delete $compar20_dup->{$key};
	}
	else {
	  $newBRH++ if($type21 eq 'BRH');
		$newRHS++ if($type21 eq 'RHS');
	}
}
print("$count20 total homologies in compara20\n");
print("$count21 total homologies in compara21\n");
printf("%1.1f%% same BRH ($sameBRH/$BRHCount)\n", scalar($sameBRH/$BRHCount*100.0));
printf("%1.1f%% same RHS ($sameRHS/$RHSCount)\n", scalar($sameRHS/$RHSCount*100.0));
print("$BRH2RHS converted BRH20 -> RHS21\n");
print("$RHS2BRH converted RHS20 -> BRH21\n");
print("$newBRH new BRH Homologies\n");
print("$newRHS new RHS Homologies\n");
print(scalar(keys(%compara20_dup)) . " lost homologies\n"); 
