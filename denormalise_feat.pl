

use DBI;

$db = "yadda";
$host = "ecs1a";

my $dsn = "DBI:mysql:database=$db;host=$host;";
  
my $user = "ensro";
my $password = undef;
  
my $dbh = DBI->connect("$dsn","$user",$password, {RaiseError => 1});



my $sth = $dbh->prepare("select c.id,s.chr_start,s.chr_end,s.raw_start,s.raw_ori from static_golden_path as s,contig as c where c.internal_id = s.raw_id");

$sth->execute();

while( my ($id,$start,$end,$raw_start,$raw_ori) = $sth->fetchrow_array() ) {
    my $h = {};
    $h->{'start'} = $start;
    $h->{'end'} = $end;
    $h->{'raw'} = $raw_start;
    $h->{'raw_ori'} = $raw_ori;
    $contig{$id} = $h;
}

while( <> ) {
    
