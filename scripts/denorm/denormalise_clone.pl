

use DBI;

$db = "mouse_sc011015_alistair";
$host = "ecs1a";

open(S,"/scratch4/ensembl/birney/static_mouse.txt");

while( <S> ) {
    my ($id,$chr,$start,$end,$raw_start,$raw_end,$raw_ori) = split;
    my $h = {};
    #print STDERR "Storing $chr,$start,$end for $id\n";
    $h->{'chr'} = $chr;
    $h->{'start'} = $start;
    $h->{'end'} = $end;
    $h->{'raw'} = $raw_start;
    $h->{'raw_ori'} = $raw_ori;
    $contig{$id} = $h;
}



while( <> ) {
    my($ct,$super,$clone) = split;
    $clone =~ s/\.\w$//g;

    #print STDERR "Mapping $clone to ",$contig{$ct}->{'chr'},"\n";

    if( !exists $clonechr{$clone} ) {
        $clonechr{$clone} = $contig{$ct}->{'chr'};
    } else {
        if( $clonechr{$clone} ne $contig{$ct}->{'chr'} ) {
	    $badclone{$clone} = 1;
	}
    }

   # now store clone position

    if( !exists $clonepos{$clone} ) {
	$clonepos{$clone} = [];
    }

    push(@{$clonepos{$clone}},$contig{$ct}->{'start'});
    push(@{$clonepos{$clone}},$contig{$ct}->{'end'});

}

foreach $clone ( keys %clonepos ) {
    if( $badclone{$clone} == 1 ) {
	print "Clone $clone is across chromosomes\n";
	next;
    } 
    @pos = sort { $a <=> $b } @{$clonepos{$clone}};
    $start = shift @pos;
    $end   = pop   @pos;

    print "Mapped $clone $clonechr{$clone} $start $end\n";
}


exit(0);


my $dsn = "DBI:mysql:database=$db;host=$host;";
  
my $user = "ensro";
my $password = undef;
  
my $dbh = DBI->connect("$dsn","$user",$password, {RaiseError => 1});



my $sth = $dbh->prepare("select c.id,s.chr_name,s.chr_start,s.chr_end,s.raw_start,s.raw_ori from static_golden_path as s,contig as c where c.internal_id = s.raw_id");

$sth->execute();

while( my ($id,$chr,$start,$end,$raw_start,$raw_ori) = $sth->fetchrow_array() ) {
    my $h = {};
    print STDERR "Storing $chr,$start,$end for $id\n";
    $h->{'chr'} = $chr;
    $h->{'start'} = $start;
    $h->{'end'} = $end;
    $h->{'raw'} = $raw_start;
    $h->{'raw_ori'} = $raw_ori;
    $contig{$id} = $h;
}





















